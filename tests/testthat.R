# Uitvoeren vanuit de repository: Rscript tests/testthat.R
# Geen setup.R: de tests gebruiken alleen pure helpers en lokale fixtures.
local({
  root <- here::here()
  test_env <- new.env(parent = globalenv())
  source(file.path(root, "scripts", "0_algemeen", "stofindicatoren.R"), local = test_env)
  source(file.path(root, "scripts", "0_algemeen", "stoffenboek.R"), local = test_env)
  testthat::test_dir(file.path(root, "tests", "testthat"), env = test_env)
})