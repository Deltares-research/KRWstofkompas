# Bouw een echt Quarto HTML-book zonder de oorspronkelijke rapporten te wijzigen.
# Publieke API: maak_stoffenboek(paths, root, export = NULL, render = TRUE).

.boek_quote <- function(x) encodeString(enc2utf8(as.character(x)), quote = '"')

# Gebruik dezelfde R-versie en bibliotheek als de actieve sessie (ook vanuit uvr).
render_stoffen_quarto <- function(...) {
  oud <- Sys.getenv(c("QUARTO_R", "R_LIBS", "UVR_LIBRARY"), unset = NA_character_)
  on.exit({
    for (naam in names(oud)) {
      if (is.na(oud[[naam]])) Sys.unsetenv(naam) else do.call(Sys.setenv, stats::setNames(list(oud[[naam]]), naam))
    }
  })
  Sys.setenv(QUARTO_R = R.home("bin"),
             R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep),
             UVR_LIBRARY = .libPaths()[1])
  quarto::quarto_render(...)
}

.boek_pad <- function(x, must_work = TRUE) {
  normalizePath(x, winslash = "/", mustWork = must_work)
}

.boek_schrijf <- function(tekst, bestand) {
  dir.create(dirname(bestand), recursive = TRUE, showWarnings = FALSE)
  writeLines(enc2utf8(tekst), bestand, useBytes = TRUE)
  invisible(bestand)
}

.boek_zonder_yaml <- function(x) {
  if (length(x) && identical(trimws(x[1]), "---")) {
    einde <- which(trimws(x[-1]) %in% c("---", "..."))[1] + 1L
    if (is.na(einde)) stop("Niet-afgesloten YAML in rapporttemplate.")
    x <- x[-seq_len(einde)]
  }
  x
}

.boek_id <- function(x) {
  x <- tolower(gsub("[^A-Za-z0-9-]+", "-", x))
  x <- gsub("^-+|-+$", "", x)
  ifelse(nzchar(x), x, "stof")
}

.boek_prefix_id <- function(id, prefix) {
  # Quarto herkent verwijzingen alleen wanneer fig-/tbl-/sec- vooraan blijft.
  soort <- regmatches(id, regexpr("^(fig|tbl|sec)-", id))
  if (length(soort) && nzchar(soort)) {
    paste0(soort, prefix, "-", substring(id, nchar(soort) + 1L))
  } else {
    paste0(prefix, "-", id)
  }
}

.boek_labels <- function(teksten, prefix) {
  labels <- unlist(lapply(teksten, function(x) {
    regels <- grep("^#\\|\\s*label:", x, value = TRUE)
    sub("[\"']$", "", sub("^#\\|\\s*label:\\s*[\"']?", "", trimws(regels)))
  }), use.names = FALSE)
  if (anyDuplicated(labels)) stop("Dubbele chunklabels in de rapporttemplates.")
  nieuw <- vapply(labels, function(x) .boek_prefix_id(.boek_id(x), prefix), character(1))
  if (anyDuplicated(nieuw)) stop("Chunklabels botsen na normalisatie.")
  stats::setNames(nieuw, labels)
}

.boek_transformeer <- function(x, prefix, labels, child = FALSE) {
  x <- .boek_zonder_yaml(x)
  # Langste namen eerst, zodat bijvoorbeeld @fig-kaart-extra intact blijft.
  for (oud in names(labels)[order(nchar(names(labels)), decreasing = TRUE)]) {
    x <- gsub(paste0("@", oud), paste0("@", labels[[oud]]), x, fixed = TRUE)
  }
  in_code <- FALSE
  start <- NA_integer_
  for (i in seq_along(x)) {
    if (grepl("^```\\{r[ ,}]", x[i])) {
      in_code <- TRUE
      start <- i
    } else if (in_code && grepl("^```\\s*$", x[i])) {
      in_code <- FALSE
    } else if (in_code && grepl("^#\\|\\s*label:", x[i])) {
      oud <- sub("[\"']$", "", sub("^#\\|\\s*label:\\s*[\"']?", "", trimws(x[i])))
      if (child) {
        # knit_child leest een gewone knitr-header; labels met spaties en
        # uitsluitend Quarto #| labels worden daar niet betrouwbaar verwerkt.
        x[start] <- sub("\\{r\\s*\\}", paste0("{r ", labels[[oud]], "}"), x[start])
        x[i] <- ""
      } else {
        x[i] <- paste0("#| label: ", labels[[oud]])
      }
    } else if (!in_code && grepl("^#{1,6} ", x[i])) {
      x[i] <- paste0("#", x[i])
    }
    # Deze rapporten schrijven ook tabsetkoppen en geen-gegevenskoppen via cat.
    if (in_code) {
      x[i] <- gsub('cat("# ', 'cat("## ', x[i], fixed = TRUE)
      x[i] <- gsub('cat("### ', 'cat("#### ', x[i], fixed = TRUE)
    }
  }
  # Expliciete anchors en lokale links; automatische anchors volgen via Lua.
  vervang <- function(regel, patroon, functie) {
    m <- gregexpr(patroon, regel, perl = TRUE)
    waarden <- regmatches(regel, m)[[1]]
    if (length(waarden)) regmatches(regel, m) <- list(vapply(waarden, functie, character(1)))
    regel
  }
  vapply(x, function(regel) {
    regel <- vervang(regel, "\\{#[A-Za-z][A-Za-z0-9_.:-]*", function(z) {
      paste0("{#", .boek_prefix_id(substring(z, 3), prefix))
    })
    vervang(regel, "\\]\\(#[A-Za-z][A-Za-z0-9_.:-]*", function(z) {
      paste0("](#", .boek_prefix_id(substring(z, 4), prefix))
    })
  }, character(1), USE.NAMES = FALSE)
}

.boek_kopieer <- function(van, naar) {
  dir.create(dirname(naar), recursive = TRUE, showWarnings = FALSE)
  if (!isTRUE(file.copy(van, naar, overwrite = FALSE, copy.date = TRUE))) {
    stop("Kopiëren mislukt: ", van, " -> ", naar)
  }
  if (!identical(unname(tools::md5sum(van)), unname(tools::md5sum(naar)))) {
    stop("Controle na kopiëren mislukt: ", naar)
  }
  invisible(naar)
}

.boek_pinnen <- function(export, paths) {
  bestanden <- unlist(export$bestanden, use.names = TRUE)
  if (!length(bestanden) || anyNA(bestanden) || any(!file.exists(bestanden))) {
    stop("De indicatorenexport bevat geen geldige vastgezette bronbestanden.")
  }
  bestanden <- vapply(bestanden, .boek_pad, character(1))
  # Ook de kaart- en lijnbestanden worden eenmaal gekozen, niet per hoofdstuk.
  extra <- list(
    gis_waterlichaam = "rds", gis_stroomgebied = "rds",
    chemtrend_meetpunten = "parquet", chemtrend_lowess_landelijk = "parquet",
    chemtrend_lowline_meetpunt = "parquet"
  )
  for (naam in names(extra)) {
    patroon <- paste0("^", naam, "(_[0-9]{8})?\\.", extra[[naam]], "$")
    if (!any(grepl(patroon, basename(bestanden)))) {
      kandidaten <- sort(list.files(paths$interim, pattern = patroon, full.names = TRUE))
      if (length(kandidaten)) bestanden[naam] <- .boek_pad(tail(kandidaten, 1))
    }
  }
  as.list(bestanden)
}

# Alleen voorbereiden is mogelijk met render = FALSE; er wordt dan niets gepubliceerd.
maak_stoffenboek <- function(paths, root = here::here(), export = NULL, render = TRUE) {
  root <- .boek_pad(root)
  template_dir <- file.path(root, "scripts", "2_rapport_templates")
  if (is.null(export)) export <- maak_indicatoren_export(paths)
  vereist <- c("indicatoren", "stoffen", "bestanden", "export_dir")
  if (!all(vereist %in% names(export))) stop("Onvolledig resultaat van maak_indicatoren_export().")
  stoffen <- export$stoffen
  velden <- c("stof", "heeft_toestand", "heeft_trend", "heeft_emissie")
  if (!all(velden %in% names(stoffen)) || !nrow(stoffen) ||
      anyNA(stoffen$stof) || any(!nzchar(stoffen$stof)) || anyDuplicated(stoffen$stof)) {
    stop("Stoffen moeten unieke, niet-lege stofcodes en beschikbaarheidskolommen hebben.")
  }
  if (!all(vapply(stoffen[velden[-1]], is.logical, logical(1))) ||
      anyNA(stoffen[velden[-1]])) stop("Beschikbaarheidsvlaggen moeten TRUE/FALSE zijn.")
  indicatoren <- export$indicatoren
  if (!"stof" %in% names(indicatoren) || anyDuplicated(indicatoren$stof) ||
      !setequal(indicatoren$stof, stoffen$stof)) stop("Indicatoren en stoffen sluiten niet een-op-een aan.")
  stoffen <- stoffen[order(tolower(stoffen$stof), stoffen$stof, method = "radix"), , drop = FALSE]
  stoffen$hoofdstuk <- sprintf("stof-%04d-%s.qmd", seq_len(nrow(stoffen)), .boek_id(stoffen$stof))
  stoffen$prefix <- sub("\\.qmd$", "", stoffen$hoofdstuk)

  run_id <- paste0(format(Sys.time(), "%Y%m%dT%H%M%S"), "-", Sys.getpid(), "-",
                   basename(tempfile(pattern = "run-")))
  werk <- file.path(root, "_stoffenboek", run_id)
  if (dir.exists(werk)) stop("Runmap bestaat al: ", werk)
  dir.create(werk, recursive = TRUE, showWarnings = FALSE)
  werk <- .boek_pad(werk)
  export_dir <- .boek_pad(export$export_dir)
  for (bestand in c("stofindicatoren.csv", "stofindicatoren.rds")) {
    if (!file.exists(file.path(export_dir, bestand))) stop("Ontbrekende export: ", bestand)
  }
  if (!isTRUE(all.equal(readRDS(file.path(export_dir, "stofindicatoren.rds")), indicatoren))) {
    stop("RDS-export verschilt van de aangeleverde indicatoren.")
  }
  downloads <- list.files(export_dir, recursive = TRUE, full.names = TRUE)
  downloads <- downloads[!file.info(downloads)$isdir]
  for (bestand in downloads) {
    relatief <- substring(.boek_pad(bestand), nchar(export_dir) + 2L)
    .boek_kopieer(bestand, file.path(werk, "downloads", relatief))
  }
  bronbestanden <- .boek_pinnen(export, paths)
  saveRDS(bronbestanden, file.path(werk, "bronbestanden.rds"))
  readr::write_csv(stoffen, file.path(werk, "hoofdstukken.csv"))
  saveRDS(list(paths = paths, stoffen = stoffen, root = root), file.path(werk, "boekcontext.rds"))
  .boek_kopieer(file.path(template_dir, "stofrapport.css"), file.path(werk, "stofrapport.css"))

  master_pad <- file.path(template_dir, "stofrapport.qmd")
  master <- .boek_zonder_yaml(readLines(master_pad, warn = FALSE, encoding = "UTF-8"))
  partial_paden <- list.files(template_dir, pattern = "^[0-9]{2}_.*\\.qmd$", full.names = TRUE)
  partial_paden <- partial_paden[!grepl("00_rangschikking\\.qmd$", partial_paden)]
  partials <- stats::setNames(lapply(partial_paden, readLines, warn = FALSE, encoding = "UTF-8"),
                             basename(partial_paden))
  if (!"00_samenvatting.qmd" %in% names(partials) ||
      !any(grepl("00_samenvatting.qmd", master, fixed = TRUE))) {
    stop("Gedeelde samenvatting ontbreekt; rond eerst de rapportintegratie af.")
  }
  for (i in seq_len(nrow(stoffen))) {
    rij <- stoffen[i, , drop = FALSE]
    prefix <- rij$prefix
    map <- file.path(werk, "partials", prefix)
    dir.create(map, recursive = TRUE, showWarnings = FALSE)
    labels <- .boek_labels(c(list(master), partials), prefix)
    body <- .boek_transformeer(master, prefix, labels)
    # here::i_am verankert here vóór setup ook binnen het gegenereerde project.
    # De absolute source werkt tevens wanneer Quarto een andere cwd kiest.
    setup_expr <- 'here::here("scripts", "0_algemeen", "setup.R")'
    body <- gsub(setup_expr, .boek_quote(file.path(root, "scripts", "0_algemeen", "setup.R")),
                 body, fixed = TRUE)
    herschrijf <- function(x) {
      for (naam in names(partials)) {
        bestemming <- .boek_quote(.boek_pad(file.path(map, naam), FALSE))
        x <- gsub(paste0('here::here("scripts", "2_rapport_templates", "', naam, '")'),
                  bestemming, x, fixed = TRUE)
        # Quarto include-paden blijven relatief aan het hoofdstuk.
        x <- gsub(paste0("{{< include ", naam, " >}}"),
                  paste0("{{< include partials/", prefix, "/", naam, " >}}"), x, fixed = TRUE)
      }
      x
    }
    for (naam in names(partials)) {
      child <- any(grepl(paste0('"', naam, '"'), master, fixed = TRUE))
      .boek_schrijf(herschrijf(.boek_transformeer(partials[[naam]], prefix, labels, child)),
                    file.path(map, naam))
    }
    params <- as.list(rij[1, velden])
    params$indicatoren_bestand <- file.path(werk, "downloads", "stofindicatoren.rds")
    params$bronbestanden <- bronbestanden
    saveRDS(params, file.path(map, "params.rds"))
    bootstrap <- c(
      "```{r}", paste0("#| label: ", prefix, "-boekcontext"), "#| include: false",
      "local({",
      paste0("  vorige_map <- setwd(", .boek_quote(root), ")"),
      "  on.exit(setwd(vorige_map))",
      "  here::i_am(\"scripts/4_maak_stoffenboek.R\")", "})",
      paste0("params <- readRDS(", .boek_quote(file.path(map, "params.rds")), ")"),
      "```", ""
    )
    # Zet na de gedeelde setup de bronselectie vast, ook voor detailkaarten.
    positie <- grep("source\\(", body)[1]
    if (is.na(positie)) stop("Setup-source niet gevonden in rapporttemplate.")
    pin_code <- c(
      paste0("paths <- readRDS(", .boek_quote(file.path(werk, "boekcontext.rds")), ")$paths"),
      "nieuwste_bestand <- function(map, naam, ext = \"parquet\") {",
      "  bestanden <- unlist(params$bronbestanden, use.names = FALSE)",
      "  patroon <- paste0(\"^\", naam, \"(_[0-9]{8})?\\\\.\", ext, \"$\")",
      "  gevonden <- unique(bestanden[grepl(patroon, basename(bestanden))])",
      "  if (length(gevonden) != 1L) stop(\"Geen unieke vastgezette bron voor: \", naam)",
      "  gevonden[[1]]", "}",
      "lees_gis <- function(naam) readRDS(nieuwste_bestand(paths$interim, naam, ext = \"rds\"))"
    )
    body <- append(body, pin_code, after = positie)
    body <- herschrijf(body)
    titel <- paste0(rij$stof)
    .boek_schrijf(c("---", paste0("title: ", .boek_quote(titel)),
                    paste0("stof-prefix: ", prefix), "---", "", bootstrap, body),
                  file.path(werk, rij$hoofdstuk))
  }
  index <- readLines(file.path(template_dir, "00_rangschikking.qmd"), warn = FALSE, encoding = "UTF-8")
  .boek_schrijf(index, file.path(werk, "index.qmd"))
  # Pandoc kent nu ook door R gegenereerde koppen: alle anchors worden uniek.
  .boek_schrijf(c(
    "local prefix = ''", "local function scoped(id)",
    "  if id == '' or id:find(prefix, 1, true) then return id end",
    "  local kind, rest = id:match('^(fig%-)(.*)$')",
    "  if not kind then kind, rest = id:match('^(tbl%-)(.*)$') end",
    "  if not kind then kind, rest = id:match('^(sec%-)(.*)$') end",
    "  return kind and (kind .. prefix .. '-' .. rest) or (prefix .. '-' .. id)", "end",
    "return {{Meta = function(m)",
    "  prefix = m['stof-prefix'] and pandoc.utils.stringify(m['stof-prefix']) or ''",
    "end}, {Header = function(h)",
    "  if prefix ~= '' then h.identifier = scoped(h.identifier) end", "  return h", "end,",
    "Link = function(l)",
    "  if prefix ~= '' and l.target:sub(1, 1) == '#' then l.target = '#' .. scoped(l.target:sub(2)) end",
    "  return l", "end}}"
  ), file.path(werk, "stof-anchors.lua"))
  .boek_schrijf(c(
    "project:", "  type: book", "  output-dir: _book", "  resources:", "    - downloads/**",
    "book:", "  title: \"KRW Stofkompas\"", "  search: true", "  sidebar:",
    "    style: docked", "    collapse-level: 1", "  chapters:", "    - index.qmd",
    paste0("    - ", stoffen$hoofdstuk), "lang: nl", "format:", "  html:",
    "    css: stofrapport.css", "    toc: true", "    toc-depth: 3",
    "    number-sections: false", "    embed-resources: false", "filters:",
    "  - stof-anchors.lua", "execute:", "  echo: false", "  warning: false",
    "  message: false", "  freeze: false", "  cache: false"
  ), file.path(werk, "_quarto.yml"))
  manifest <- list(run_id = run_id, status = "prepared", created = Sys.time(), root = root,
                   project = werk, export_dir = export_dir, bestanden = bronbestanden,
                   bron_md5 = tools::md5sum(unlist(bronbestanden)), hoofdstukken = stoffen)
  saveRDS(manifest, file.path(werk, "manifest.rds"))
  if (!isTRUE(render)) return(invisible(manifest))
  render_stoffen_quarto(input = werk, execute_dir = werk, quiet = FALSE)
  lokaal <- file.path(werk, "_book")
  verwacht <- c("index.html", sub("\\.qmd$", ".html", stoffen$hoofdstuk),
                "downloads/stofindicatoren.csv", "downloads/stofindicatoren.rds", "search.json")
  if (any(!file.exists(file.path(lokaal, verwacht)))) {
    stop("Onvolledig gerenderd boek: ", paste(verwacht[!file.exists(file.path(lokaal, verwacht))], collapse = ", "))
  }
  for (hoofdstuk in verwacht[grepl("^stof-.*\\.html$", verwacht)]) {
    html <- paste(readLines(file.path(lokaal, hoofdstuk), warn = FALSE), collapse = "\n")
    h1 <- regmatches(html, gregexpr("<h1(?:[ >])", html, perl = TRUE))[[1]]
    if (length(h1) != 1L) stop("Geen uniek H1-hoofdstuk in: ", hoofdstuk)
    if (grepl("quarto-unresolved-ref", html, fixed = TRUE)) {
      stop("Onopgeloste kruisverwijzing in: ", hoofdstuk)
    }
  }
  if (!identical(unname(tools::md5sum(unlist(bronbestanden))), unname(manifest$bron_md5))) {
    stop("Bronbestanden zijn tijdens de boekbouw gewijzigd; boek niet gepubliceerd.")
  }
  doel <- file.path(paths$output, "stoffenboek", run_id)
  if (dir.exists(doel)) stop("Publicatiemap bestaat al: ", doel)
  boom <- list.files(lokaal, recursive = TRUE, all.files = TRUE, full.names = TRUE, no.. = TRUE)
  boom <- boom[!file.info(boom)$isdir]
  relatief <- substring(.boek_pad(boom), nchar(.boek_pad(lokaal)) + 2L)
  for (j in seq_along(boom)) .boek_kopieer(boom[j], file.path(doel, relatief[j]))
  manifest$status <- "published"
  manifest$published <- Sys.time()
  manifest$output_dir <- .boek_pad(doel)
  manifest$index <- file.path(manifest$output_dir, "index.html")
  manifest$files <- data.frame(path = relatief, bytes = file.info(boom)$size,
                               md5 = unname(tools::md5sum(boom)))
  # Het manifest is het laatste bestand: een mislukte kopie is geen publicatie.
  saveRDS(manifest, file.path(werk, "manifest.rds"))
  .boek_kopieer(file.path(werk, "manifest.rds"), file.path(doel, "manifest.rds"))
  invisible(manifest)
}