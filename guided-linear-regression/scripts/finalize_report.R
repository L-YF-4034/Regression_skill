# Run only after the interactive analysis has finished. Never infer completion
# from approval alone; completed_stages must reflect successful execution.
write_final_report <- function(template,output,params,completed_stages,
                               analysis_finished=FALSE,render=TRUE,quarto_bin=Sys.which("quarto")) {
 if(!isTRUE(analysis_finished)) stop("Finish the analysis before generating the report")
 valid<-c("exploration","vif","fit","diagnostics","boxcox_profile","boxcox","influence")
 if(!length(completed_stages) || any(!completed_stages%in%valid) || anyDuplicated(completed_stages)) stop("Provide successfully completed stages")
 dependencies<-list(vif="exploration",fit="vif",diagnostics="fit",
                    boxcox_profile="diagnostics",boxcox="boxcox_profile",influence="fit")
 for(stage in completed_stages) if(!all(dependencies[[stage]]%in%completed_stages)) stop("Completed stages have missing prerequisites")
 permissions<-c(vif="selection_confirmed",fit="approve_fit",diagnostics="approve_diagnostics",
                boxcox_profile="approve_boxcox_profile",boxcox="approve_boxcox",influence="approve_influence")
 for(stage in intersect(completed_stages,names(permissions))) if(!isTRUE(params[[permissions[[stage]]]])) stop("A completed stage lacks approval")
 if("fit"%in%completed_stages && !isTRUE(params$model_confirmed)) stop("Model specification was not confirmed")
 template<-normalizePath(template,mustWork=TRUE,winslash="/")
 lines<-readLines(template,encoding="UTF-8",warn=FALSE)
 delim<-which(lines=="---");if(length(delim)<2 || delim[1]!=1) stop("Invalid QMD frontmatter")
 meta<-yaml::yaml.load(paste(lines[2:(delim[2]-1)],collapse="\n"))
 for(nm in names(params)) {
  value<-params[[nm]]
  # R/Quarto parameters that contain mappings need an explicit value field.
  meta$params[nm]<-list(if(!is.null(value) && (is.list(value) || !is.null(names(value)))) list(value=value) else value)
 }
 meta$params$analysis_finished<-TRUE
 # Keep authorization parameters separate from the actual completion log.
 meta$analysis_completed_stages<-as.character(completed_stages)
 if(!is.null(meta$params$data_file)) {
  data_path<-normalizePath(meta$params$data_file,mustWork=TRUE,winslash="/")
  meta$params$data_file<-basename(data_path)
 }
 body<-lines[(delim[2]+1):length(lines)]
 active<-FALSE;in_code<-FALSE;keep<-logical(length(body))
 setup_done<-FALSE
 for(i in seq_along(body)) {
  line<-body[i]
  if(!in_code && grepl("^<!-- stage: [a-z_]+ -->$",line)) {
   stage<-sub("^<!-- stage: ([a-z_]+) -->$","\\1",line)
   active<-stage%in%c(completed_stages,"setup","reproducibility")
   setup_done<-TRUE
   next
  }
  if(grepl("^```",line)) in_code<-!in_code
  keep[i]<-if(setup_done) active else TRUE
 }
 selected<-body[keep]
 # Headings/code/text of unfinished stages are removed, not merely eval=FALSE.
 counter<-0L
 selected<-vapply(selected,function(line) {
  if(grepl("^## Code [0-9]+",line)) {
   counter<<-counter+1L;line<-sub("^## Code [0-9]+",paste("## Code",counter),line)
  }
  line
 },character(1),USE.NAMES=FALSE)
 if(!grepl("\\.qmd$",output,ignore.case=TRUE)) stop("Output must end in .qmd")
 dir.create(dirname(output),recursive=TRUE,showWarnings=FALSE)
 out_dir<-normalizePath(dirname(output),mustWork=TRUE,winslash="/")
 output<-file.path(out_dir,basename(output))
 script<-normalizePath(file.path(dirname(template),"..","scripts","regression.R"),mustWork=TRUE,winslash="/")
 dest_script<-file.path(out_dir,"regression.R")
 if(!identical(script,dest_script) && !file.copy(script,dest_script,overwrite=TRUE)) stop("Could not copy regression.R")
 if(exists("data_path",inherits=FALSE)) {
  dest_data<-file.path(out_dir,basename(data_path))
  if(!identical(data_path,dest_data) && !file.copy(data_path,dest_data,overwrite=TRUE)) stop("Could not copy CSV")
 }
 writeLines(c("---",yaml::as.yaml(meta),"---",selected),output,useBytes=TRUE)
 result<-list(qmd=output,completed_stages=completed_stages,pdf=NULL)
 if(render) {
  if(length(quarto_bin)!=1 || !nzchar(quarto_bin) || !file.exists(quarto_bin)) stop("QMD saved, but Quarto executable is unavailable")
  status<-system2(quarto_bin,c("render",shQuote(output),"--to","pdf"))
  pdf<-sub("\\.qmd$",".pdf",output,ignore.case=TRUE)
  if(status!=0 || !file.exists(pdf)) stop("QMD saved, but PDF compilation failed")
  result$pdf<-pdf
 }
 invisible(result)
}
