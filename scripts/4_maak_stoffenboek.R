# Stap 4: exporteer indicatoren en bouw/publiceer het volledige Quarto HTML-book.
# Uitvoeren vanuit de repository; elke run krijgt een nieuwe map, zonder opruimen.
root <- normalizePath(here::here(), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "0_algemeen", "setup.R"))

# Testfase: uitsluitend deze vier stoffen. Zet selectie = NULL voor alle stoffen.
test_stoffen <- c("As", "Cd", "Pb", "PFOS")
indicatoren_export <- maak_indicatoren_export(paths, selectie = test_stoffen)
stoffenboek <- maak_stoffenboek(paths = paths, root = root, export = indicatoren_export)
stoffenboek$index