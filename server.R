 #' @title Logica del servidor para la aplicacion Gage R&R
 #'
 #' @description
 #' Implementa el flujo reactivo de la aplicacion Shiny: carga de datos,
 #' seleccion de columnas, ejecucion del analisis Gage R&R, generacion de
 #' graficos y consulta opcional a OpenAI para interpretar resultados.
 #'
 #' @keywords internal
 NULL
 
 #' Logica del servidor principal de la aplicacion
 #'
 #' @param input Entradas reactivas de Shiny.
 #' @param output Salidas reactivas de Shiny.
 #' @param session Sesion activa de Shiny.
 #'
 #' @return No devuelve valor. Registra reactividad y salidas en la sesion.
 #' @export
 server <- function(input, output, session) {
   #' Convierte resultados tabulares a un formato visible en Shiny
   #'
   #' @param x Objeto tabular o salida ANOVA.
   #'
   #' @return Un `data.frame` listo para `renderTable()` o `NULL`.
   as_display_table <- function(x) {
     if (is.null(x)) {
       return(NULL)
     }

    if (inherits(x, "summary.aov") && length(x) > 0) {
      x <- x[[1]]
    }

    df <- as.data.frame(x)
     df <- cbind(Termino = rownames(df), df, row.names = NULL)
     df
   }
 
   #' Prepara una o varias columnas de medicion para `ss.rr`
   #'
   #' @param df `data.frame` fuente.
   #' @param measurement_cols Nombres de columnas numericas de medicion.
   #' @param part_col Nombre de la columna que identifica la pieza.
   #' @param appr_col Nombre de la columna que identifica al evaluador.
   #'
   #' @return Una lista con datos preparados, nombre de variable y etiqueta.
   prepare_ss_rr_input <- function(df, measurement_cols, part_col, appr_col) {
     measurement_cols <- unique(measurement_cols)
 
     if (length(measurement_cols) == 1) {
      return(list(
        data = df,
        var_name = measurement_cols[[1]],
        label = measurement_cols[[1]]
      ))
    }

    stacked <- do.call(
      rbind,
      lapply(measurement_cols, function(col_name) {
        data.frame(
          .gage_rr_value = df[[col_name]],
          .gage_rr_measurement = col_name,
          .gage_rr_part = df[[part_col]],
          .gage_rr_appr = df[[appr_col]],
          stringsAsFactors = FALSE,
          check.names = FALSE
        )
      })
    )

    names(stacked)[names(stacked) == ".gage_rr_part"] <- part_col
    names(stacked)[names(stacked) == ".gage_rr_appr"] <- appr_col

    list(
      data = stacked,
      var_name = ".gage_rr_value",
       label = paste(measurement_cols, collapse = " + ")
     )
   }
 
   #' Ejecuta `ss.rr` para una variable de medicion preparada
   #'
   #' @param df `data.frame` listo para analisis.
   #' @param var_name Nombre de la columna de medicion a usar.
   #' @param part_col Nombre de la columna de pieza.
   #' @param appr_col Nombre de la columna de evaluador.
   #' @param print_plot Indica si debe renderizar el grafico.
   #'
   #' @return El objeto devuelto por `SixSigma::ss.rr`.
   run_ss_rr_for_var <- function(df, var_name, part_col, appr_col, print_plot = FALSE) {
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
      var = var_name,
      part = part_col,
      appr = appr_col,
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
 
   #' Genera el grafico Gage R&R en un archivo PNG
   #'
   #' @param path Ruta del archivo de salida.
   #' @param width Ancho del PNG en pixeles.
   #' @param height Alto del PNG en pixeles.
   #' @param res Resolucion del PNG.
   #'
   #' @return Invisiblemente, la ruta del archivo generado.
   build_rr_plot <- function(path, width = 2400, height = 3200, res = 200) {
     grDevices::png(filename = path, width = width, height = height, res = res)
     on.exit(grDevices::dev.off(), add = TRUE)
     prepared <- prepared_analysis_input()
    run_ss_rr_for_var(
      df = prepared$data,
      var_name = prepared$var_name,
       part_col = input$part_col,
       appr_col = input$appr_col,
       print_plot = TRUE
     )
     invisible(path)
   }

  is_excel_file <- reactive({
    req(input$file)
    tolower(tools::file_ext(input$file$name)) %in% c("xls", "xlsx")
  })

  output$sheet_control <- renderUI({
    req(input$file)
    if (!is_excel_file()) {
      return(NULL)
    }

    if (!requireNamespace("readxl", quietly = TRUE)) {
      return(
        p("Para leer Excel instala el paquete ", code("readxl"), ".")
      )
    }

    sheets <- readxl::excel_sheets(input$file$datapath)
    selectInput("sheet", "Hoja", choices = sheets, selected = sheets[[1]])
  })

  data_reactive <- reactive({
    req(input$file)
    read_input_data(
      path = input$file$datapath,
      header = input$header,
      sep = or_default(input$sep, ","),
      quote = or_default(input$quote, '"'),
      dec = or_default(input$dec, "."),
      sheet = if (is_excel_file()) input$sheet else NULL
    )
  })

  output$column_controls <- renderUI({
    req(data_reactive())
    df <- data_reactive()
    cols <- names(df)
    numeric_cols <- cols[vapply(df, is.numeric, logical(1))]
    default_vars <- if (length(numeric_cols) > 0) numeric_cols else cols[[1]]
    first_measurement <- if (length(default_vars) > 0) default_vars[[1]] else cols[[1]]
    remaining_cols <- setdiff(cols, default_vars)
    default_part <- if (length(remaining_cols) > 0) remaining_cols[[1]] else first_measurement
    remaining_cols <- setdiff(remaining_cols, default_part)
    default_appr <- if (length(remaining_cols) > 0) remaining_cols[[1]] else default_part

    labeled_cols <- vapply(
      cols,
      function(col) {
        cls <- class(df[[col]])[[1]]
        sprintf("%s (%s)", col, cls)
      },
      character(1)
    )
    choice_values <- stats::setNames(cols, labeled_cols)

    tagList(
      selectizeInput(
        "var_cols",
        "Columnas de medicion",
        choices = choice_values,
        selected = default_vars,
        multiple = TRUE,
        options = list(plugins = list("remove_button"))
      ),
      selectInput("part_col", "Columna de parte", choices = choice_values, selected = default_part),
      selectInput("appr_col", "Columna de evaluador", choices = choice_values, selected = default_appr)
    )
  })

  prepared_analysis_input <- reactive({
    req(data_reactive(), input$var_cols, input$part_col, input$appr_col)
    prepare_ss_rr_input(
      df = data_reactive(),
      measurement_cols = input$var_cols,
      part_col = input$part_col,
      appr_col = input$appr_col
    )
  })

  analysis_result <- eventReactive(input$run_analysis, {
    req(data_reactive(), input$var_cols, input$part_col, input$appr_col)

    df <- data_reactive()
    measurement_cols <- input$var_cols
    needed <- c(measurement_cols, input$part_col, input$appr_col)
    validate(
      need(length(measurement_cols) >= 1, "Selecciona al menos una columna de medicion."),
      need(length(unique(needed)) == length(needed), "Las columnas de medicion, parte y evaluador deben ser diferentes."),
      need(all(needed %in% names(df)), "Las columnas seleccionadas no existen en el archivo."),
      need(
        all(vapply(df[measurement_cols], is.numeric, logical(1))),
        "Todas las columnas de medicion deben ser numericas."
      ),
      need(!isTRUE(input$use_manual_tolerance) || input$tolerance > 0, "La tolerancia debe ser mayor que cero."),
      need(
        isTRUE(input$use_manual_tolerance) || isTRUE(input$usl > input$lsl),
        "USL debe ser mayor que LSL cuando la tolerancia se calcula automaticamente."
      )
    )

    prepared <- prepare_ss_rr_input(
      df = df,
      measurement_cols = measurement_cols,
      part_col = input$part_col,
      appr_col = input$appr_col
    )

    captured <- NULL
    result <- NULL

    captured <- capture.output({
      result <- run_ss_rr_for_var(
        df = prepared$data,
        var_name = prepared$var_name,
        part_col = input$part_col,
        appr_col = input$appr_col,
        print_plot = FALSE
      )
    })

    list(
      result = result,
      log = paste(captured, collapse = "\n"),
      label = prepared$label,
      measurement_count = length(measurement_cols)
    )
  })

  output$active_measurement_control <- renderUI({
    req(analysis_result())

    tags$div(
      style = "padding: 1rem 1rem 0 1rem;",
      tags$div(
        style = "font-size: 0.95rem; color: #4b5563;",
        if (analysis_result()$measurement_count > 1) {
          sprintf(
            "Analisis concatenado de %s columnas de medicion: %s",
            analysis_result()$measurement_count,
            analysis_result()$label
          )
        } else {
          sprintf("Columna de medicion: %s", analysis_result()$label)
        }
      )
    )
  })

  current_result <- reactive({
    req(analysis_result())
    analysis_result()$result
  })

  current_log <- reactive({
    req(analysis_result())
    analysis_result()$log
  })

  interpretation_result <- eventReactive(input$run_interpretation, {
    req(current_result(), analysis_result())

    tryCatch(
      {
        plot_file <- tempfile(fileext = ".png")
        build_rr_plot(plot_file)

        withProgress(message = "Consultando OpenAI", value = 0.2, {
          incProgress(0.4)
          text <- openai_interpret_rr(
            rr_result = current_result(),
            plot_path = plot_file,
            language = "es",
            extra_instructions = paste(
              "Contexto del analisis:",
              analysis_result()$label,
              if (nzchar(or_default(input$interpretation_instructions, ""))) input$interpretation_instructions else ""
            )
          )
          incProgress(0.4)
          list(ok = TRUE, text = text)
        })
      },
      error = function(e) {
        list(ok = FALSE, text = conditionMessage(e))
      }
    )
  })

  output$data_status <- renderUI({
    if (is.null(input$file)) {
      return(p("Carga un archivo CSV o Excel para habilitar el analisis."))
    }

    df <- data_reactive()
    tagList(
      p(sprintf("Filas: %s", nrow(df))),
      p(sprintf("Columnas: %s", ncol(df)))
    )
  })

  output$data_preview <- renderTable({
    req(data_reactive())
    utils::head(data_reactive(), 12)
  }, rownames = TRUE)

  output$analysis_log <- renderText({
    req(current_log())
    current_log()
  })

  output$anova_table <- renderTable({
    req(current_result())
    as_display_table(current_result()$anovaTable)
  }, rownames = TRUE)

  output$anova_reduced_table <- renderTable({
    req(current_result())
    anova_red <- current_result()$anovaRed
    validate(need(!is.null(anova_red), "No se genero ANOVA reducida para este analisis."))
    as_display_table(anova_red)
  }, rownames = TRUE)

  output$var_comp_table <- renderTable({
    req(current_result())
    as_display_table(current_result()$varComp)
  }, rownames = TRUE)

  output$study_var_table <- renderTable({
    req(current_result())
    as_display_table(current_result()$studyVar)
  }, rownames = TRUE)

  output$ncat_text <- renderText({
    req(current_result())
    as.character(current_result()$ncat)
  })

  output$rr_plot <- renderImage({
    req(current_result())
    outfile <- tempfile(fileext = ".png")
    build_rr_plot(outfile)
    list(
      src = outfile,
      contentType = "image/png",
      alt = "Grafico Gage R&R"
    )
  }, deleteFile = TRUE)

  observeEvent(input$copy_plot, {
    req(current_result())
    session$sendCustomMessage("copy-rr-plot", list())
  })

  observeEvent(input$copy_plot_status, {
    status <- input$copy_plot_status
    req(is.list(status), !is.null(status$status), !is.null(status$detail))

    showNotification(
      status$detail,
      type = if (identical(status$status, "success")) "message" else "error"
    )
  })

  output$download_excel <- downloadHandler(
    filename = function() {
      label <- gsub("[^A-Za-z0-9_-]+", "-", analysis_result()$label)
      sprintf("gage-rr-%s-%s.xlsx", label, Sys.Date())
    },
    content = function(file) {
      req(current_result())

      plot_file <- tempfile(fileext = ".png")
      build_rr_plot(plot_file)

      interpretation_text <- NULL
      if (isTruthy(input$run_interpretation) && input$run_interpretation > 0) {
        interpretation_text <- interpretation_result()$text
      }

      write_rr_export_workbook(
        path = file,
        rr_result = current_result(),
        plot_path = plot_file,
        interpretation_text = interpretation_text
      )
    }
  )

  output$interpretation_status <- renderText({
    req(current_result())

    if (input$run_interpretation < 1) {
      return("Sin consumir tokens. Pulsa 'Generar interpretacion' para consultar OpenAI.")
    }

    if (isTRUE(interpretation_result()$ok)) {
      "Interpretacion generada."
    } else {
      "No se pudo generar la interpretacion."
    }
  })

  output$interpretation_text <- renderUI({
    req(interpretation_result())
    card(
      card_body(
        tags$div(
          style = paste(
            "white-space: pre-wrap; line-height: 1.5;",
            if (isTRUE(interpretation_result()$ok)) "" else "color: #b91c1c;"
          ),
          interpretation_result()$text
        )
      )
    )
  })
}
