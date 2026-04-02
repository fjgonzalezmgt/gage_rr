library(shiny)

if (file.exists("openai_helpers.R")) {
  source("openai_helpers.R", local = TRUE)
}

or_default <- function(x, default) {
  if (is.null(x) || identical(x, "")) {
    default
  } else {
    x
  }
}

read_delimited_data <- function(path, header, sep, quote, dec) {
  utils::read.table(
    file = path,
    header = header,
    sep = sep,
    quote = quote,
    dec = dec,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

read_input_data <- function(path, header, sep, quote, dec, sheet = NULL) {
  ext <- tolower(tools::file_ext(path))

  if (ext %in% c("xls", "xlsx")) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      stop(
        paste(
          "El paquete 'readxl' no esta instalado.",
          "Instalalo con install.packages('readxl')."
        ),
        call. = FALSE
      )
    }

    return(as.data.frame(readxl::read_excel(path = path, sheet = sheet)))
  }

  read_delimited_data(
    path = path,
    header = header,
    sep = sep,
    quote = quote,
    dec = dec
  )
}

run_ss_rr <- function(df, input, print_plot = FALSE) {
  if (!requireNamespace("SixSigma", quietly = TRUE)) {
    stop(
      paste(
        "El paquete 'SixSigma' no esta instalado.",
        "Instalalo con install.packages('SixSigma')."
      ),
      call. = FALSE
    )
  }

  tolerance_value <- if (isTRUE(input$use_manual_tolerance)) {
    input$tolerance
  } else {
    input$usl - input$lsl
  }

  SixSigma::ss.rr(
    var = input$var_col,
    part = input$part_col,
    appr = input$appr_col,
    lsl = input$lsl,
    usl = input$usl,
    sigma = input$sigma,
    tolerance = tolerance_value,
    data = df,
    main = input$plot_title,
    sub = input$plot_subtitle,
    alphaLim = input$alpha_lim,
    errorTerm = input$error_term,
    digits = input$digits,
    method = input$method,
    print_plot = print_plot,
    signifstars = input$signif_stars
  )
}
