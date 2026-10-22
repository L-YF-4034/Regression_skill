configure <- function() {
 options(digits=7,contrasts=c("contr.treatment","contr.poly"))
 RNGkind("Mersenne-Twister","Inversion","Rejection"); set.seed(20261020)
}
model_spec <- function(d,y,xs,degrees=NULL,center=TRUE,centers=NULL) {
 if(length(y)!=1 || !length(xs) || anyDuplicated(xs) || y %in% xs || !all(c(y,xs)%in%names(d))) stop("Select one Y and distinct X variables")
 if(any(grepl("`",c(y,xs),fixed=TRUE))) stop("Backticks in variable names are unsupported")
 deg<-setNames(rep(1L,length(xs)),xs)
 if(length(degrees)) {
  if(is.null(names(degrees)) || any(!names(degrees)%in%xs) || anyDuplicated(names(degrees))) stop("degrees must name selected predictors")
  deg[names(degrees)]<-degrees
 }
 if(any(!is.finite(deg)) || any(deg<1 | deg!=floor(deg))) stop("degrees must be positive integers")
 ct<-setNames(numeric(0),character(0));rhs<-character()
 for(x in xs) {
  a<-d[[x]];q<-paste0("`",x,"`")
  if(is.character(a)) stop("Convert categorical X to factor with confirmed reference level")
  if(deg[x]>1) {
   if(!is.numeric(a) || any(!is.finite(a)) || length(unique(a))<=deg[x]) stop("Polynomial X needs finite numeric values and more unique values than degree")
   ct[x]<-if(!is.null(centers) && x%in%names(centers)) centers[[x]] else if(center) mean(a) else 0
   if(!is.finite(ct[x])) stop("Invalid centering constant")
   u<-paste0("(",q," - ",sprintf("%.17g",ct[x]),")")
   rhs<-c(rhs,paste0("I(",u,"^",seq_len(deg[x]),")"))
  } else rhs<-c(rhs,q)
 }
 ff<-as.formula(paste(paste0("`",y,"`"),"~",paste(rhs,collapse=" + ")))
 list(formula=ff,degrees=deg,centers=ct,center=center,
      model_type=if(any(deg>1)) "polynomial regression" else if(length(xs)==1) "simple linear regression" else "multiple regression")
}
vif_design <- function(d,y,xs,degrees=NULL,center=TRUE,centers=NULL,selection_confirmed=FALSE) {
 if(!isTRUE(selection_confirmed)) stop("Confirm Y and X before VIF")
 spec<-model_spec(d,y,xs,degrees,center,centers)
 # Build X only; do not fit the selected response before regression approval.
 mm<-model.matrix(delete.response(terms(spec$formula)),data=d,na.action=na.fail)
 if(nrow(mm)!=nrow(d) || any(!is.finite(mm))) stop("Resolve missing or nonfinite X before VIF")
 x<-mm[,colnames(mm)!="(Intercept)",drop=FALSE]
 if(!ncol(x)) stop("No predictor columns")
 if(nrow(mm)-ncol(mm)<=1) stop("Insufficient residual degrees of freedom for proposed design")
 rank_ok<-qr(mm)$rank==ncol(mm)
 ans<-vapply(seq_len(ncol(x)),function(j) {
  ss<-sum((x[,j]-mean(x[,j]))^2)
  if(ss<=0) return(Inf)
  if(ncol(x)==1) return(1)
  aux<-lm.fit(cbind(1,x[,-j,drop=FALSE]),x[,j])
  unexplained<-sum(aux$residuals^2)/ss
  if(unexplained<1e-12) Inf else max(1,1/unexplained)
 },numeric(1))
 tab<-data.frame(design_column=colnames(x),VIF=ans,tolerance=1/ans,
 recommendation=ifelse(!is.finite(ans),"Exact/near dependency: resolve before fitting",ifelse(ans>=10,"High collinearity: inspect",ifelse(ans>=5,"Potential collinearity: inspect","No strong VIF signal"))))
 print(list(model_type=spec$model_type,formula=spec$formula,degrees=spec$degrees,centers=spec$centers,full_rank=rank_ok));print(tab)
 if(ncol(x)==1) cat("One design column: VIF=1 by definition; this is not an independence test.\n")
 cat("Column-level VIF (factor dummy columns separately), not term-level GVIF. Thresholds 5 and 10 are heuristics; do not auto-delete predictors.\n")
 invisible(list(table=tab,spec=spec,full_rank=rank_ok))
}
fit_model <- function(d,y,xs,approved=FALSE,degrees=NULL,center=TRUE,centers=NULL) {
 if(!isTRUE(approved)) stop("尚未確認迴歸")
 spec<-model_spec(d,y,xs,degrees,center,centers)
 f<-lm(spec$formula,data=d,x=TRUE,y=TRUE,na.action=na.fail)
 if(f$rank<ncol(model.matrix(f)) || df.residual(f)<=1) stop("秩或自由度不足")
 attr(f,"regression_spec")<-spec
 f
}
fit_output <- function(f,d,y,xs,show_summary=TRUE) {
 if(show_summary) {print(summary(f)); print(confint(f))}
 if(length(xs)==1 && is.numeric(d[[xs]])) {
 plot(d[[xs]],d[[y]],xlab=xs,ylab=y,pch=19)
 nd<-d[rep(1,200),,drop=FALSE];nd[[xs]]<-seq(min(d[[xs]]),max(d[[xs]]),length.out=200)
 lines(nd[[xs]],predict(f,newdata=nd),col=2,lwd=2)
 } else {
 plot(fitted(f),d[[y]],xlab="Fitted",ylab="Observed",pch=19); abline(0,1,col=2)
 for(x in xs) if(is.numeric(d[[x]])) {
 nd<-d[rep(1,100),,drop=FALSE]
 for(z in xs) nd[[z]]<-if(is.numeric(d[[z]])) median(d[[z]]) else if(is.factor(d[[z]])) factor(rep(levels(d[[z]])[1],100),levels=levels(d[[z]])) else stop("類別X須先設factor並確認參考組")
 nd[[x]]<-seq(min(d[[x]]),max(d[[x]]),length.out=100)
 plot(d[[x]],d[[y]],xlab=x,ylab=y,pch=19)
 lines(nd[[x]],predict(f,newdata=nd),col=2,lwd=2)
 title(sub="Other X fixed at medians / reference group")
 }
 }
}
diagnostics <- function(f,approved=FALSE,ordered=FALSE) {
 if(!isTRUE(approved)) stop("尚未確認殘差分析")
 e<-resid(f); fv<-fitted(f)
 plot(fv,e,xlab="Fitted",ylab="Residuals",pch=19); abline(h=0,col=2)
 qqnorm(e,pch=19); qqline(e,col=2)
 plot(fv,sqrt(abs(rstandard(f))),xlab="Fitted",ylab="Sqrt abs studentized residual",pch=19)
 mf<-model.frame(f); for(x in names(mf)[-1]) {plot(mf[[x]],e,xlab=x,ylab="Residuals");abline(h=0,col=2)}
 sw<-if(length(e)>=3 && length(e)<=5000) shapiro.test(e) else NULL
 bp<-lmtest::bptest(f,studentize=TRUE)
 dw<-lmtest::dwtest(f,alternative="two.sided")
 if(!is.null(sw)) print(sw)
 print(bp);print(dw)
 if(!ordered) cat("DW uses current data row order; no verified time/sampling order. Interpret as an order-dependent diagnostic, not proof of error independence.\n")
 invisible(list(shapiro=sw,bp=bp,dw=dw,order_verified=ordered))
}
boxcox_profile <- function(f,approved=FALSE) {
 if(!isTRUE(approved)) stop("Box-Cox approval required")
 if(any(model.response(model.frame(f))<=0)) stop("Box-Cox requires positive Y")
 grid<-seq(-2,2,.01)
 for(attempt in seq_len(5)) {
  bc<-MASS::boxcox(f,lambda=grid,plotit=FALSE,interp=FALSE)
  j<-which.max(bc$y);cutoff<-max(bc$y)-qchisq(.95,1)/2
  if(j>1 && j<length(grid) && bc$y[1]<cutoff && tail(bc$y,1)<cutoff) break
  if(attempt==5) stop("Profile maximum or CI is at boundary; inspect wider search")
  grid<-seq(min(grid)-2,max(grid)+2,.01)
 }
 inside<-which(bc$y>=cutoff);lo<-min(inside);hi<-max(inside)
 ci<-c(approx(bc$y[c(lo-1,lo)],bc$x[c(lo-1,lo)],xout=cutoff)$y,
       approx(bc$y[c(hi,hi+1)],bc$x[c(hi,hi+1)],xout=cutoff)$y)
 plot(bc$x,bc$y,type="l",xlab=expression(lambda),ylab="Profile log-likelihood",main="Box-Cox profile (95% CI)")
 abline(h=cutoff,lty=2,col="gray40");abline(v=ci,lty=3,col="#087e8b")
 abline(v=bc$x[j],col="#c54b35",lwd=2)
 legend("topright",c("Estimated lambda","95% profile CI","95% cutoff"),
        col=c("#c54b35","#087e8b","gray40"),lty=c(1,3,2),bty="n")
 result<-list(lambda_hat=bc$x[j],CI95=ci,grid=bc$x,loglik=bc$y)
 print(list(lambda_hat=result$lambda_hat,CI95=result$CI95))
 invisible(result)
}
transform_model <- function(f,d,y,xs,approved=FALSE,lambda=NULL,profile=NULL) {
 if(!isTRUE(approved)) stop("尚未確認Box-Cox")
 if(any(d[[y]]<=0)) stop("Y須為正值")
 if(is.null(profile)) profile<-boxcox_profile(f,approved=TRUE)
 chosen_by<-if(is.null(lambda)) "estimated" else "user"
 if(is.null(lambda)) lambda<-profile$lambda_hat
 if(!is.numeric(lambda) || length(lambda)!=1 || !is.finite(lambda)) stop("lambda must be one finite number")
 print(list(lambda_hat=profile$lambda_hat,CI95=profile$CI95,lambda_used=lambda,chosen_by=chosen_by))
 d$.transformed_y<-if(abs(lambda)<1e-8) log(d[[y]]) else expm1(lambda*log(d[[y]]))/lambda
 spec<-attr(f,"regression_spec")
 transformed_fit<-fit_model(d,".transformed_y",xs,TRUE,degrees=spec$degrees,
                            center=if(is.null(spec)) TRUE else spec$center,centers=spec$centers)
 list(fit=transformed_fit,data=d,lambda=lambda,
      lambda_hat=profile$lambda_hat,CI95=profile$CI95,chosen_by=chosen_by)
}
influence_output <- function(f,approved=FALSE,alpha=.05) {
 if(!isTRUE(approved)) stop("尚未確認離群分析")
 n<-nobs(f); p<-f$rank; stopifnot(n-p-1>0)
 z<-data.frame(row_id=rownames(model.frame(f)),leverage=hatvalues(f),internal=rstandard(f),external=rstudent(f),cook=cooks.distance(f),dffits=dffits(f))
 z$max_abs_dfbetas<-apply(abs(dfbetas(f)),1,max)
 z$high_leverage<-z$leverage>2*p/n
 z$internal_flag<-abs(z$internal)>3
 z$outlier_bonferroni<-abs(z$external)>qt(1-alpha/(2*n),n-p-1)
 z$cook_over_1<-z$cook>1;z$cook_screen<-z$cook>4/n
 z$dffits_screen<-abs(z$dffits)>2*sqrt(p/n)
 z$dfbetas_screen<-z$max_abs_dfbetas>2/sqrt(n)
 flag_names<-c("high_leverage","internal_flag","outlier_bonferroni","cook_over_1","cook_screen","dffits_screen","dfbetas_screen")
 marked<-rowSums(z[flag_names],na.rm=TRUE)>0
 issue<-z[marked,,drop=FALSE]
 if(nrow(issue)) {
  issue$flag_reason<-apply(issue[flag_names],1,function(a) paste(flag_names[which(a)],collapse=", "))
  print(issue)
  cat("DFBETAS for flagged samples only:\n")
  print(dfbetas(f)[marked,,drop=FALSE])
 } else cat("沒有被所用門檻標記的離群值或影響樣本。\n")
 attr(issue,"n_total")<-n
 attr(issue,"thresholds")<-list(leverage=2*p/n,external=qt(1-alpha/(2*n),n-p-1),
  cook=c(1,4/n),dffits=2*sqrt(p/n),dfbetas=2/sqrt(n))
 invisible(issue)
}
