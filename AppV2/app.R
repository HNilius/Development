#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
library(shiny)
library(shinydashboard)
library(bsplus)
library(readxl)
library(xlsx)
library(openxlsx)
library(stringr)
library(rmarkdown)
library(pdftools)
library(shinyFeedback)

# JS script
create_sheet_precision <-
  function(name,
           n_row = 5,
           n_col = 5,
           n_lvl = 2,
           lvl_names = NULL) {
    if (is.null(lvl_names)) {
      lvl_names <- paste("Level", c(1:n_lvl))
    }
    res_sheet <-
      matrix(c("Methode:", NA, name, rep(NA, (n_col + 1) * 2 - 3)), ncol = n_col +
               1)
    names_day <- paste(rep("Tag", n_col), c(1:n_col))
    names_rep <- paste(rep("Replikat", n_row), c(1:n_row))
    for (i in 1:n_lvl) {
      tmp <-
        matrix(c(lvl_names[i], rep(NA, (n_row + 2) * (n_col + 1) - 1)), nrow = n_row +
                 2, ncol = n_col + 1)
      tmp[-c(1, nrow(tmp)), 1] <- names_rep
      tmp[1, -1] <- names_day
      res_sheet <- rbind(res_sheet, tmp)
    }
    return(res_sheet)
  }

create_sheet_legacy <- function(names_legacy, n_lvl = 2) {
  res_sheet <- matrix(rep(NA, 2 + n_lvl * 2), ncol =  2 + n_lvl * 2)
  colnames(res_sheet) <-
    c(names_legacy, paste0("Serie.L", c(1:n_lvl)),
      paste0("DtoD.L", c(1:n_lvl)))
  return(res_sheet)
}

create_sheet_metadata <-
  function(n_row = 5,
           n_col = 5,
           n_lvl = 2,
           tv = rep(NULL, n_lvl),
           name,
           cvr = rep(NULL, n_lvl),
           cvil = rep(NULL, n_lvl),
           abias = rep(NULL, n_lvl),
           name_legacy = rep(NULL, n_lvl),
           fct = rep(NULL, n_lvl),
           sampletype = "Serum",
           unit = unit,
           ate_low = 0,
           ate_high = 0,
           relate = 0,
           precbias_yn = FALSE,
           legacy_yn = FALSE,
           method_yn = FALSE,
           tae_yn = FALSE) {
    res_sheet <- matrix(
      c(
        name,
        rep(NA, n_lvl - 1),
        n_row,
        rep(NA, n_lvl - 1),
        n_col,
        rep(NA, n_lvl - 1),
        n_lvl,
        rep(NA, n_lvl - 1),
        tv,
        cvr,
        cvil,
        abias,
        name_legacy,
        rep(NA, n_lvl - 2),
        fct,
        rep(NA, n_lvl - 1),
        sampletype,
        rep(NA, n_lvl - 1),
        unit,
        rep(NA, n_lvl - 1),
        ate_low,
        ate_high,
        rep(NA, n_lvl - 2),
        relate,
        rep(NA, n_lvl - 1),
        precbias_yn,
        rep(NA, n_lvl - 1),
        legacy_yn,
        rep(NA, n_lvl - 1),
        method_yn,
        rep(NA, n_lvl - 1),
        tae_yn,
        rep(NA, n_lvl - 1)
      )
      ,
      ncol = 18
    )
    colnames(res_sheet) <- c(
      "name",
      "n_rep",
      "n_days",
      "n_lvl",
      "tv",
      "cvr",
      "cvil",
      "abias",
      "name_legacy",
      "fct",
      "sampletype",
      "unit",
      "ATE",
      "relate",
      "precbias_yn",
      "legacy_yn",
      "method_yn",
      "tae_yn"
    )
    return(res_sheet)
  }

create_Wb <- function(sheetlist) {
  nulllist <- lapply(sheetlist, is.null)
  wb <- createWorkbook()
  if (nulllist[[1]] == FALSE) {
    addWorksheet(wb, "Präzision und Bias")
    tmp_bias <- data.frame(sheetlist[[1]])
    writeData(wb, sheet = 1, tmp_bias, colNames = FALSE)
  }
  if (nulllist[[2]] == FALSE) {
    addWorksheet(wb, "Legacy")
    tmp_leg <- data.frame(sheetlist[[2]])
    writeData(wb, sheet = "Legacy", tmp_leg, colNames = TRUE)
  }
  if (nulllist[[4]] == FALSE) {
    addWorksheet(wb, "Methodenvergleich")
    tmp_met <- data.frame(sheetlist[[4]])
    writeData(wb, sheet = "Methodenvergleich", tmp_met, colNames = TRUE)
  }
  if (nulllist[[5]] == FALSE) {
    addWorksheet(wb, "Totaler analytischer Fehler")
    tmp_tae <- data.frame(sheetlist[[5]])
    writeData(wb, sheet = "Totaler analytischer Fehler", tmp_tae, colNames = TRUE)
  }
  addWorksheet(wb, "NICHT BEARBEITEN")
  metadata <- data.frame(sheetlist[[3]])
  metadata[is.na(metadata)] <- ""
  writeData(wb, sheet = "NICHT BEARBEITEN", metadata, colNames = TRUE)
  print(wb)
  return(wb)
}

create_sheet_method_tae <- function(name_legacy) {
  res <- data.frame(matrix(rep(NA, 2), ncol = 2))
  colnames(res) <- name_legacy
  return(res)
}


# Define UI for application
ui <- dashboardPage(
  # Application title
  dashboardHeader(
    title = img(
      src = "ILVA.png",
      height = 50,
      width = 100
    ),
    titleWidth = 185
  ),
  
  #    dashboardHeader(img(src = "toradihit.png", height = 50, width = 200),windowTitle = "TORADI-HIT"),
  #    fluidRow(column(4, HTML('<h4><span style="color: #ee2832;"><strong>A multivariable prediction model for the rapid diagnosis of heparin-induced thrombocytopenia (HIT)</strong></span></h4')),
  #             column(8,HTML('<p>&nbsp;</p>'))),
  #    fluidRow(column(4, HTML('<p>&nbsp;&nbsp;</p>')),
  #             column(8, HTML("<p>&nbsp;&nbsp;</p>"))),
  #   fluidRow(
  #        column(4,HTML("<h4><strong>Intended use:</strong></h4>
  #<h5>To estimate the risk of HIT in individual patients at the bedside.
  #                      The diagnostic algorithm was validated in patients <em>with suspected HIT</em> and not for screening purposes.</h5>")
  #        ),
  #        column(8,HTML("<p>&nbsp;&nbsp;</p>"))
  #    ),
  #    h3(strong("A multivariable prediction model for the rapid diagnosis of heparin-induced thrombocytopenia (HIT)")))))
  #, windowTitle = "TORADI-HIT")
  # Sidebar with a slider input for number of bins
  dashboardSidebar(
    sidebarMenu(
      menuItem(
        "Einführung",
        tabName = "landing",
        icon = icon("vial", verify_fa = FALSE)
      ),
      menuItem(
        "Excel-Datei",
        tabName = "xlsx",
        icon = icon("file", verify_fa = FALSE)
      ),
      menuItem(
        "Auswertung",
        tabName = "calc",
        icon = icon("gears", verify_fa = FALSE)
      )
    )
    ,
    collapsed = FALSE,
    disable = FALSE
  ),
  dashboardBody(
    tabItems(
      tabItem(
        tabName = "landing",
        fluidRow(
          style = "display:flex;",
          column(box(
            div(img(src = "Insel.svg", height = 150), style = "text-align: center;"),
            HTML(
              '<h3 style="text-align: center;">&Uuml;ber die Applikation</h3>'
            ),
            HTML(
              '<p style="text-align: justify;">Diese Web-Applikation dient der Planung und der Auswertung von Verifikationsexperimenten nach den Vorgaben des Clinical and Laboratory Standards Institute (CLSI). Momentan werden drei Guidelines unterst&uuml;tzt:</p>
<ul>
<li style="text-align: left;"><em>CLSI 15-A3: User Verification of Precision and Estimation of Bias</li>
<li style="text-align: left;">CLSI 09C: Measurement Procedure Comparison and Bias Estimation Using Patients Samples</li>
<li style="text-align: left;">CLSI 21: Evaluation of Total Analytical Error for Quantitative Medical Laboratory Measurement Procesdures </em></li>
</ul>
                             <p style="text-align: justify;"> Die Auswertung beruht auf automatischen R Markdown Skripts. Der Source Code ist verfügbar <a href="https://github.com/" target="_blank">hier.</a></p>'
            ),
            height = 550,
            width = 12
          ), width = 4),
          column(
            box(
              div(img(src = "Anleitung.svg", height = 150), style = "text-align: center;"),
              HTML('<h3 style="text-align: center;">Anleitung</h3>'),
              HTML(
                '<p>Eine kurze &Uuml;bersicht &uuml;ber den Versuchsaufbau, Anforderungen und Ziele der einzelnen Guidelines kann &uuml;ber den Knopf unten gedownloaded werden. Im Tab <strong>"Excel-Datei"</strong> k&ouml;nnen dann die Vorgaben f&uuml;r den Test eingegeben werden und es wird eine Excel-Datei erstellt, die zur Datensammlung benutzt werden kann. Das Arbeitsblatt "NICHT BEARBEITEN" in der Excel-Datei speichert die angegebenen Vorgaben und sollte nicht bearbeitet werden, da ansonsten der Verifikationsbericht ggf.
                             nicht richtig erstellt werden kann. Im Tab <strong>"Auswertung"</strong> kann die ausgef&uuml;llte Excel-Datei hochgeladen werden und ein Verifikationsbericht wird erstellt. Optional besteht auch die M&ouml;glichkeit, hier die Packungsbeilage anzuf&uuml;gen.</p>'
              ),
              downloadButton("download_anleitung", "Anleitung downloaden"),
              height = 550,
              width = 12
            ),
            width = 4 
          ),
          column(box(
            div(img(src = "Questions.svg", height = 150), style = "text-align: center;"),
            HTML('<h3 style="text-align: center;">Fragen und Anregungen</h3>'),
            HTML(
              '<p>F&uuml;r Fragen und Anregungen stehen wir gerne zur Verf&uuml;gung. Bitte schreiben Sie uns eine<a href="mailto:henning.nilius@insel.ch?subject=Feedback&body=Message">
Email
</a>.</p>'
            ),
            HTML(
              '<p>Diese Applikation wurde erstellt von:</p>
                        <ul>
                        <li>Henning Nilius (FAMH-Kandidat Klinische Chemie)</li>
                        <li>Manuel Gn&auml;gi (FAMH-Kandidat Klinische Chemie)</li>
                        <li>Michael Nagler (FAMH H&auml;matologie (und Klinische Chemie))</li>
                        </ul>'
            ),
            height = 550,
            width = 12
          ),
          width = 4)
        ),
        fluidRow(column(
          div(a(
            img(
              src = "Logo.png",
              height = 72 ,
              width = "auto"
            ),
            href = "http://www.zlm.insel.ch/de/"
          ),
          style = "text-align: right;"), width = 6
        ),
        column(
          div(a(
            img(
              src = "pcd.png",
              height = 72 ,
              width = "auto"
            ),
            href = "https://pcd-research.ch/"
          ),
          style = "text-align: left;"), width = 6
        )),
        fluidRow(HTML("<br><br><br>"))
      ),
      tabItem(
        tabName = "xlsx",
        fluidRow(
          box(
            textInput("name", label = HTML("Name des Tests"), value = NULL),
            textInput("material", label = HTML("Material")),
            textInput(
              "unit",
              label = HTML("Einheit des gemessenen Analytes"),
              value = NULL
            ),
            checkboxGroupInput(
              "ana",
              label = HTML("Geplante Verifizierungsschritte"),
              choices = list(
                "Präzision und Bias nach CLSI 15-A3" = 1,
                "Methodenvergleich nach CLSI 09c" = 3,
                "Totaler analytischer Fehler nach CLSI 21" = 4
                #,"Legacy" = 2
              ),
              selected = NULL
            ),
            uiOutput("warningsUI")
          , width = 4),
          conditionalPanel(
            "input.ana.includes('1')",
            box(
              HTML(
                "<p><strong>Eingaben für Präzision und Bias nach CLSI EP15-A3</strong></p>"
              ),
              numericInput(
                "n_rep",
                label = HTML("Anzahl der geplanten Replikate"),
                min = 5,
                max = 550,
                value = 5
              ),
              numericInput(
                "n_days",
                label = HTML("Anzahl der geplanten Tage"),
                min = 5,
                max = 550,
                value = 5
              ),
              numericInput(
                "n_lvl",
                label = HTML("Anzahl der geplanten zu überprüfenden Levels"),
                min = 2,
                max = 10,
                value = NULL
              ),
              uiOutput("uitv"),
              uiOutput("uicvr"),
              uiOutput("uicvwl"),
              uiOutput("uiabias"),
              numericInput(
                "relate",
                label = HTML("Maximal erlaubte Messunsicherheit in %"),
                min = 0,
                value = NULL
              )
            , width = 4)
          ),
          conditionalPanel(
            "input.ana.includes('2')",
            box(
              HTML("<p><strong>Eingaben für den alten Bericht</strong></p>"),
              textInput(
                "name_comp",
                label = HTML("Name des Vergleichtests"),
                value = NULL
              ),
              numericInput(
                "fct",
                label = HTML("Faktor für die Messunsicherheit"),
                value = 2
              ),
              conditionalPanel(
                "!input.ana.includes('1')",
                numericInput(
                  "n_lvl_2",
                  label = HTML("Anzahl der geplanten zu überprüfenden Levels"),
                  min = 2,
                  max = 10,
                  value = NULL
                ),
                uiOutput("uitv2")
              )
            , width = 4)
          ),
          conditionalPanel(
            "input.ana.includes('3') || input.ana.includes('4')",
            box(
              HTML(
                "<p><strong>Eingaben für den Methodenvergleich nach CLSI EP-A9
                                        und totaler analytischer Fehler nach CLSI EP-A21 </strong></p>"
              ),
              textInput(
                "name_comp2",
                label = HTML("Name des Vergleichtests"),
                value = NULL
              ),
              conditionalPanel(
                "input.ana.includes('4')",
                numericInput(
                  "ate_low",
                  "Unteres Limit des absoluten erlaubten totalen Fehler (bitte mit -)",
                  value = NULL
                ),
                numericInput(
                  "ate_high",
                  "Oberes Limit des absoluten erlaubten totalen Fehler",
                  value = NULL
                )
              )
              
            , width = 4)
          )
          
        )
      ),
      tabItem(tabName = "calc",
              box(
                fileInput(
                  "xlsxfile",
                  HTML("Hier bitte die vorher erstellte Excel-Datei hochladen", accept = ".xlsx")
                ),
                fileInput(
                  "pack",
                  HTML("Optional: Packungsbeilage hier hochladen als PDF"),
                  accept = ".pdf"
                ),
                downloadButton("download_tab_2", "Verifizierungsbericht downloaden")
              ),)
    ),
    tags$head(tags$style(
      HTML(
        '.skin-black .main-sidebar  {color: #FFFFFF; background-color: #ffffff;}
                    .skin-black .span12 { background-color: #ffffff;}
                    .skin-black .main-header .navbar  { background-color: #ffffff;}
                    .skin-black .main-header > .logo { background-color: #ffffff;}
                    .skin-black .main-header > .logo:hover { background-color: #ffffff;}
                    .skin-black .main-header .logo, .skin-black .main-header .navbar { transition: color 0s; }'
      )
    )),
    tags$head(tags$link(rel = "shortcut icon", href = "favicon.ico"))
  ),
  title = "Insel Laboratory Verification App",
  skin = "black"
)

# Define server logic required to draw a histogram
server <- function(input, output, session) {
  output$debug <- renderText(input$pack)
  output$uitv <- renderUI({
    req(input$n_lvl)
    lvl_ids <- paste("Zielwert_Level", c(1:input$n_lvl), sep = "_")
    ui_elems  <- purrr::map(lvl_ids, ~ {
      output <- numericInput(
        inputId = .x,
        label = gsub("_", " ", .x),
        value = NULL
      )
      return(output)
    })
    return(tagList(ui_elems))
  })
  output$uitv2 <- renderUI({
    req(input$n_lvl_2)
    lvl_ids <- paste("Zielwert_Level", c(1:input$n_lvl_2), sep = "_")
    ui_elems  <- purrr::map(lvl_ids, ~ {
      output <- numericInput(
        inputId = .x,
        label = gsub("_", " ", .x),
        value = NULL
      )
      return(output)
    })
    return(tagList(ui_elems))
  })
  output$precbias <-
    output$uicvr <-  renderUI({
      req(input$n_lvl)
      ids_cvr <- c(1:input$n_lvl)
      ui_elems_cvr  <- purrr::map(ids_cvr, ~ {
        tmp_cvr <- paste("Akzeptabler_CVr_Level", .x, sep = "_")
        output <- numericInput(inputId = tmp_cvr,
                               label = HTML(paste(
                                 "Akzeptabler CV<sub>r</sub>", "Level", .x, "[%]"
                               )),
                               value = NULL)
        return(output)
      })
      return(tagList(ui_elems_cvr))
    })
  output$uicvwl <-  renderUI({
    req(input$n_lvl)
    ids_cvwl <- c(1:input$n_lvl)
    ui_elems_cvwl  <- purrr::map(ids_cvwl, ~ {
      tmp_cvwl <- paste("Akzeptabler_CVwl_Level", .x, sep = "_")
      output <- numericInput(inputId = tmp_cvwl,
                             label = HTML(paste(
                               "Akzeptabler CV<sub>wl</sub>", "Level", .x, "[%]"
                             )),
                             value = NULL)
      return(output)
    })
    return(tagList(ui_elems_cvwl))
  })
  output$uiabias <- renderUI({
    req(input$n_lvl)
    ids <-
      paste("Akzeptabler_Bias_Level", c(1:input$n_lvl), sep = "_")
    ui_elems_abias  <- purrr::map(ids, ~ {
      output <- numericInput(
        inputId = .x,
        label = gsub("_", " ", .x),
        value = NULL
      )
      return(output)
    })
    return(tagList(ui_elems_abias))
  })
  output$download_anleitung <- downloadHandler(
    filename = function() {
      "Anleitung.pdf"
    },
    content = function(file) {
      file.copy("Anleitung.pdf", file)
    }
  )
  
  output$warningsUI <- renderUI({
     base_list <- c(input$name  == "", 
                       input$material == "", 
                       input$unit == "",
                      is.null(input$ana))
     prec_list <- FALSE
     if(1 %in% input$ana){
       prec_list_tmp_static <- c(
         !is.numeric(input$n_rep),
         !is.numeric(input$n_days),
         !is.numeric(input$relate),
         !is.numeric(input$n_lvl)
       )
       req(input$n_lvl, cancelOutput = TRUE) # Cancels the check for the dynamic IDs when n_lvl is not jet defined
       cvr_ids <- paste("Akzeptabler_CVr_Level", c(1:input$n_lvl), sep = "_")
       cvr <-
         purrr::map(cvr_ids, ~ {
           out <- !is.numeric(input[[.x]])
           return(out)
         })
       cvwl_ids <-
         paste("Akzeptabler_CVwl_Level", c(1:input$n_lvl), sep = "_")
       cvil <-
         purrr::map(cvwl_ids, ~ {
           out <- !is.numeric(input[[.x]])
           return(out)
         })
       abias_ids <-
         paste("Akzeptabler_Bias_Level", c(1:input$n_lvl), sep = "_")
       abias <-
         purrr::map(abias_ids, ~ {
           out <- !is.numeric(input[[.x]])
           return(out)
         })
       lvl_ids <-
         paste("Zielwert_Level", c(1:input$n_lvl), sep = "_")
       tmp_tv <-
         purrr::map(lvl_ids, ~ {
           out <- !is.numeric(input[[.x]])
           return(out)
         })
       prec_tmp_list <- unlist(c(prec_list_tmp_static, cvr,cvil, abias, tmp_tv))
       prec_list <- any(prec_tmp_list)
     }
     mc_list <- FALSE
     if(3 %in% input$ana){
       mc_tmp_list <- c(input$name_comp2 == "")
       mc_list <- any(mc_tmp_list)
     }
     tae_list <- FALSE
     if(4 %in% input$ana){
       tae_tmp_list <- c(input$name_comp2 == "",
                     !is.numeric(input$ate_low),
                     !is.numeric(input$ate_high))
       tae_list <- any(tae_tmp_list)
     }
     base_truth <- any(c(base_list,prec_list,mc_list,tae_list))
     if(base_truth){
       out <- list(
       "warning" = HTML('<p><span style="color: #ff0000;"><strong>Bitte alle Felder ausf&uuml;llen! 
            Ansonsten kann keine Excel-Datei erstellt werden oder der Bericht kann nicht richtig angezeigt werden.</strong></span></p>'),
         "help" = helpText("Der Downloadknopf wird verfügbar, wenn alle Felder ausgefüllt sind"))
     }else{
       out  <- downloadButton("download_tab_1", "Excel-Datei erstellen")
     }
     return(tagList(out))
    })
  
  output$download_tab_1 <- downloadHandler(
    filename = function() {
      paste("Verifzierungsplan_", input$name, ".xlsx", sep = "")
    },
    content = function(file) {
      req(input$name)
      req(input$material)
      req(input$unit)
      name <- as.character(input$name)
      sampletype <-
        as.character(input$material)
      unit <- as.character(input$unit)
      n_rep <- NA
      n_days <- NA
      n_lvl <- 2
      tv <- c(NA, NA)
      cvr <- c(NA, NA)
      cvil <- c(NA, NA)
      abias <- c(NA, NA)
      fct <- NA
      ate_low <- NA
      ate_high <- NA
      relate <- NA
      name_legacy <- c(name, NA)
      sheet_precision <- NULL
      sheet_metadata <- NULL
      sheet_legacy <- NULL
      sheet_method <- NULL
      sheet_tae <- NULL
      precbias_yn <-
        ifelse(1 %in% input$ana, TRUE, FALSE)
      legacy_yn <-
        ifelse(2 %in% input$ana, TRUE, FALSE)
      method_yn <-
        ifelse(3 %in% input$ana, TRUE, FALSE)
      tae_yn <-
        ifelse(4 %in% input$ana, TRUE, FALSE)
      if (1 %in% input$ana) {
        cvr_ids <- paste("Akzeptabler_CVr_Level", c(1:input$n_lvl), sep = "_")
        cvr <-
          purrr::map(cvr_ids, ~ {
            out <- input[[.x]]
            return(out)
          })
        cvwl_ids <-
          paste("Akzeptabler_CVwl_Level", c(1:input$n_lvl), sep = "_")
        cvil <-
          purrr::map(cvwl_ids, ~ {
            out <- input[[.x]]
            return(out)
          })
        abias_ids <-
          paste("Akzeptabler_Bias_Level", c(1:input$n_lvl), sep = "_")
        abias <-
          purrr::map(abias_ids, ~ {
            out <- input[[.x]]
            return(out)
          })
        n_rep <- as.numeric(input$n_rep)
        n_days <-
          as.numeric(input$n_days)
        relate <-
          as.numeric(input$relate)
        n_lvl <- as.numeric(input$n_lvl)
        lvl_ids <-
          paste("Zielwert_Level", c(1:input$n_lvl), sep = "_")
        tmp_tv <-
          purrr::map(lvl_ids, ~ {
            out <- input[[.x]]
            return(out)
          })
        tv <- unlist(tmp_tv)
        sheet_precision <-
          create_sheet_precision(name,
                                 n_row = n_rep,
                                 n_col = n_days,
                                 n_lvl = n_lvl)
      }
      if (2 %in% input$ana) {
        if (!1 %in% input$ana) {
          n_lvl <- as.numeric(input$n_lvl_2)
          lvl_ids <-
            paste("Zielwert_Level", c(1:input$n_lvl_2), sep = "_")
          tmp_tv <-
            purrr::map(lvl_ids, ~ {
              out <- input[[.x]]
              return(out)
            })
          tv <- unlist(tmp_tv)
          cvr <- rep(NA, n_lvl)
          cvil <- rep(NA, n_lvl)
          abias <- rep(NA, n_lvl)
        }
        name_legacy <-
          c(input$name, input$name_comp)
        fct <- as.numeric(input$fct)
        sheet_legacy <-
          create_sheet_legacy(name_legacy, n_lvl)
      }
      if (3 %in% input$ana) {
        name_legacy <- c(name, as.character(input$name_comp2))
        print(name_legacy)
        sheet_method <-
          create_sheet_method_tae(name_legacy = name_legacy)
      }
      if (4 %in% input$ana) {
        name_legacy <- c(name, as.character(input$name_comp2))
        sheet_tae <-
          create_sheet_method_tae(name_legacy = name_legacy)
        ate_low <- input$ate_low
        ate_high <- input$ate_high
      }
      sheet_metadata <-
        create_sheet_metadata(
          n_row = n_rep,
          n_col = n_days,
          n_lvl = n_lvl,
          tv = tv,
          name = name,
          cvr = cvr,
          cvil = cvil,
          abias = abias,
          name_legacy = name_legacy,
          fct = fct,
          sampletype = sampletype,
          unit = unit,
          ate_low = ate_low,
          ate_high = ate_high,
          relate = relate,
          precbias_yn = precbias_yn,
          legacy_yn = legacy_yn,
          method_yn = method_yn,
          tae_yn = tae_yn
        )
      sheet_list <-
        list(
          "Präzision und Bias" = sheet_precision,
          "Legacy" = sheet_legacy,
          "NICHT BEARBEITEN" = sheet_metadata,
          "Methodenvergleich" = sheet_method,
          "Totaler analytischer Fehler" = sheet_tae
        )
      wb <- create_Wb(sheet_list)
      print(wb)
      saveWorkbook(wb, file)
    }
  )
  output$download_tab_2 <- downloadHandler(
    filename <-
      function(file) {
        paste("Verifizerungsreport.pdf", sep = "")
      },
    content = function(file) {
      req(input$xlsxfile)
      withProgress(message = "Bericht wird erstellt. Bitte warten Sie!" , {
        inFile <- input$xlsxfile
        insert <- NULL
        if (!is.null(input$pack)) {
          tmp_in <- input$pack
          insert <- tmp_in$datapath
        }
        metadata <-
          data.frame(read_excel(
            inFile$datapath,
            sheet = "NICHT BEARBEITEN",
            col_names = TRUE
          ))
        precisionandbias <- NULL
        Precision <- as.logical(metadata$precbias_yn[1])
        legacy_df <- NULL
        Legacy <- as.logical(metadata$legacy_yn[1])
        mc <- NULL
        Method <- as.logical(metadata$method_yn[1])
        tae <- NULL
        TAE <- as.logical(metadata$tae_yn[1])
        if (Precision) {
          precisionandbias <-
            read_excel(inFile$datapath, sheet = "Präzision und Bias", skip = 2)
        }
        if (Legacy) {
          legacy_df <- read_excel(inFile$datapath, sheet = "Legacy")
        }
        if (Method) {
          mc <- read_excel(inFile$datapath, sheet = "Methodenvergleich")
        }
        if (TAE) {
          tae <-
            read_excel(inFile$datapath, sheet = "Totaler analytischer Fehler")
        }
        temp_folder <- tempdir()
        tempReport <- file.path(temp_folder,
                                "Masterfile.Rmd")
        tempTemplate <- file.path(temp_folder, "Precision.Rmd")
        tempLegacy <- file.path(temp_folder, "Legacy.Rmd")
        tempMeth <-
          file.path(temp_folder, "Methodenvergleich.Rmd")
        tempTAE <- file.path(temp_folder, "TAE.Rmd")
        file.copy("Masterfile.Rmd", tempReport, overwrite = TRUE)
        file.copy("Precision.Rmd", tempTemplate, overwrite = TRUE)
        file.copy("Legacy.Rmd", tempLegacy, overwrite = TRUE)
        file.copy("Methodenvergleich.Rmd", tempMeth, overwrite = TRUE)
        file.copy("TAE.Rmd", tempTAE, overwrite = TRUE)
        library(rmarkdown)
        out <-
          render(
            'Masterfile.Rmd',
            params = list(
              Precision =  Precision,
              precisionandbias = precisionandbias,
              Legacy = Legacy,
              legacy_df = legacy_df,
              metadata = metadata,
              Method = Method,
              mc = mc,
              TAE = TAE,
              tae = tae,
              insert = insert
            )
          )
        file.rename(out, file)
      })
    }
  )
  
  
}


# Run the application
shinyApp(ui = ui, server = server)
