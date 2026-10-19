# Hulpfuncties voor het ophalen van stofgegevens uit het RIVM-zoek­systeem.

.rivm_stof_cache <- new.env(parent = emptyenv())

.rivm_norm_text <- function(x) {
  x |>
    stringr::str_squish() |>
    stringr::str_to_lower()
}

.rivm_get_html <- function(url) {
  response <- httr::GET(
    url,
    httr::timeout(20),
    httr::user_agent("KRWstofkompas Quarto report")
  )
  httr::stop_for_status(response)
  xml2::read_html(httr::content(response, as = "raw"))
}

.rivm_get_index <- function() {
  if (is.null(.rivm_stof_cache$index)) {
    .rivm_stof_cache$index <- .rivm_get_html("https://rvszoeksysteem.rivm.nl/Stof")
  }
  .rivm_stof_cache$index
}

.rivm_stofgegevens_container <- function(page) {
  rvest::html_element(
    page,
    xpath = "//h2[normalize-space()='Stofgegevens']/ancestor::div[contains(concat(' ', normalize-space(@class), ' '), ' substance-detail ')][1]"
  )
}

.rivm_section_fields <- function(page) {
  container <- .rivm_stofgegevens_container(page)
  if (inherits(container, "xml_missing")) {
    return(list())
  }

  labels <- rvest::html_elements(container, "dt")
  label_text <- trimws(rvest::html_text2(labels))
  fields <- vector("list", length(labels))

  for (i in seq_along(labels)) {
    label_node <- labels[[i]]
    parent <- xml2::xml_parent(label_node)
    siblings <- xml2::xml_children(parent)
    sibling_paths <- xml2::xml_path(siblings)
    label_position <- match(xml2::xml_path(label_node), sibling_paths)
    if (is.na(label_position)) next

    sibling_tags <- xml2::xml_name(siblings)
    next_label <- which(seq_along(siblings) > label_position & sibling_tags == "dt")
    last_position <- if (length(next_label) > 0L) min(next_label) - 1L else length(siblings)
    value_positions <- which(
      seq_along(siblings) > label_position &
        seq_along(siblings) <= last_position &
        sibling_tags == "dd"
    )

    values <- lapply(value_positions, function(j) {
      value_node <- siblings[[j]]
      value_text <- stringr::str_squish(rvest::html_text2(value_node))
      # De structuurformule wordt via een aparte RIVM-aanvraag geladen;
      # de HTML-response bevat hier alleen een tijdelijke laadtekst.
      if (.rivm_norm_text(label_text[[i]]) == .rivm_norm_text("Structuurformule") &&
          grepl("wordt geladen", value_text, ignore.case = TRUE)) {
        value_text <- ""
      }
      links <- rvest::html_elements(value_node, "a[href]")
      list(
        text = value_text,
        links = lapply(seq_along(links), function(k) {
          list(
            text = stringr::str_squish(rvest::html_text2(links[[k]])),
            url = xml2::url_absolute(
              rvest::html_attr(links[[k]], "href"),
              "https://rvszoeksysteem.rivm.nl"
            )
          )
        })
      )
    })

    fields[[i]] <- list(
      label = stringr::str_squish(label_text[[i]]),
      values = values
    )
  }

  fields <- Filter(Negate(is.null), fields)
  stats::setNames(fields, vapply(fields, `[[`, character(1), "label"))
}

.rivm_field <- function(page, label) {
  fields <- .rivm_section_fields(page)
  found <- which(.rivm_norm_text(names(fields)) == .rivm_norm_text(label))
  if (length(found) == 0L) {
    return("")
  }

  values <- unlist(lapply(fields[found], function(field) {
    vapply(field$values, `[[`, character(1), "text")
  }), use.names = FALSE)
  paste(unique(stats::na.omit(trimws(values[nzchar(trimws(values))]))), collapse = "; ")
}

.rivm_detail_id_candidates <- function(stofnaam) {
  links <- rvest::html_elements(.rivm_get_index(), "a[href^='/stof/detail/']")
  link_names <- rvest::html_text2(links)
  same_name <- which(.rivm_norm_text(link_names) == .rivm_norm_text(stofnaam))
  if (length(same_name) == 0L) {
    return(character())
  }

  hrefs <- rvest::html_attr(links[same_name], "href")
  stringr::str_match(hrefs, "/stof/detail/([0-9]+)$")[, 2]
}

.rivm_get_detail <- function(detail_id) {
  cache_key <- paste0("detail_", detail_id)
  if (is.null(.rivm_stof_cache[[cache_key]])) {
    url <- paste0("https://rvszoeksysteem.rivm.nl/stof/detail/", detail_id)
    .rivm_stof_cache[[cache_key]] <- .rivm_get_html(url)
  }
  .rivm_stof_cache[[cache_key]]
}

.rivm_get_structure_image <- function(detail_id) {
  cache_key <- paste0("structure_", detail_id)
  if (is.null(.rivm_stof_cache[[cache_key]])) {
    image_uri <- tryCatch({
      url <- "https://rvszoeksysteem.rivm.nl/Stof/StructuralFormula"
      response <- httr::POST(
        url,
        body = list(id = detail_id),
        encode = "form",
        httr::timeout(20),
        httr::user_agent("KRWstofkompas Quarto report")
      )
      if (httr::status_code(response) %in% c(204L, 404L)) {
        ""
      } else {
        httr::stop_for_status(response)
        uri <- httr::content(response, as = "parsed", type = "application/json")
        if (is.character(uri) && length(uri) == 1L &&
            grepl("^data:image/(png|jpeg|gif|svg\\+xml);base64,", uri)) {
          uri
        } else {
          ""
        }
      }
    }, error = function(e) "")
    .rivm_stof_cache[[cache_key]] <- image_uri
  }
  .rivm_stof_cache[[cache_key]]
}

rivm_stofgegevens <- function(stofnaam, cas_nummer = "") {
  empty_result <- list(
    success = FALSE,
    message = "RIVM-stofgegevens konden niet worden opgehaald.",
    detail_id = "",
    url = "https://rvszoeksysteem.rivm.nl/Stof",
    naam = stofnaam,
    stofafkorting = "",
    cas_nummer = cas_nummer,
    eg_nummer = "",
    engelse_naam = "",
    synoniem = "",
    aquo_code = "",
    sikb_id = "",
    molecuulformule = "",
    smiles = "",
    stofgroepen = character(),
    chemische_stofgroep = "",
    velden = list(),
    echa_url = "",
    zzs_url = "",
    structuur_uri = ""
  )

  tryCatch({
    detail_ids <- .rivm_detail_id_candidates(stofnaam)
    if (length(detail_ids) == 0L) {
      empty_result$message <- "Geen exacte stofnaam gevonden in de RIVM-stoffenindex."
      return(empty_result)
    }

    for (detail_id in detail_ids) {
      page <- .rivm_get_detail(detail_id)
      page_cas <- .rivm_field(page, "CAS-nummer")
      if (nzchar(cas_nummer) && nzchar(page_cas) &&
          !cas_nummer %in% trimws(strsplit(page_cas, ";", fixed = TRUE)[[1]])) {
        next
      }

      title_node <- rvest::html_element(page, "h1")
      rivm_name <- if (inherits(title_node, "xml_missing")) stofnaam else rvest::html_text2(title_node)
      container <- .rivm_stofgegevens_container(page)
      anchors <- rvest::html_elements(container, "a[href]")
      anchor_text <- rvest::html_text2(anchors)
      anchor_href <- xml2::url_absolute(rvest::html_attr(anchors, "href"),
                                         "https://rvszoeksysteem.rivm.nl")
      echa_match <- grepl("chem.echa.europa.eu/", anchor_href, ignore.case = TRUE)
      similarity_match <- grepl("similarity", paste(anchor_text, anchor_href), ignore.case = TRUE)

      velden <- .rivm_section_fields(page)
      functionele_stofgroepen <- velden[["Functionele stofgroepen"]]
      groups <- if (is.null(functionele_stofgroepen)) {
        character()
      } else {
        vapply(functionele_stofgroepen$values, `[[`, character(1), "text")
      }

      result <- list(
        success = TRUE,
        message = "",
        detail_id = detail_id,
        url = paste0("https://rvszoeksysteem.rivm.nl/stof/detail/", detail_id),
        naam = rivm_name,
        stofafkorting = .rivm_field(page, "Stofafkorting"),
        cas_nummer = page_cas,
        eg_nummer = .rivm_field(page, "EG-nummer"),
        engelse_naam = .rivm_field(page, "Engelse naam"),
        synoniem = .rivm_field(page, "Synoniem"),
        aquo_code = .rivm_field(page, "Aquo-code"),
        sikb_id = .rivm_field(page, "SIKB-id"),
        molecuulformule = .rivm_field(page, "Molecuulformule"),
        smiles = .rivm_field(page, "SMILES"),
        stofgroepen = unique(trimws(groups[nzchar(trimws(groups))])),
        chemische_stofgroep = .rivm_field(page, "Chemische stofgroep"),
        velden = velden,
        echa_url = if (any(echa_match)) anchor_href[which(echa_match)[1]] else "",
        zzs_url = if (any(similarity_match)) anchor_href[which(similarity_match)[1]] else "",
        structuur_uri = .rivm_get_structure_image(detail_id)
      )
      return(result)
    }

    empty_result$message <- "RIVM-detailpagina niet gevonden of CAS-nummer komt niet overeen."
    empty_result
  }, error = function(e) {
    empty_result$message <- paste("RIVM-stofgegevens niet beschikbaar:", conditionMessage(e))
    empty_result
  })
}
