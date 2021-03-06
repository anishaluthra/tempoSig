#' Trinucleotide labels
#'
#' @export
trinucleotides <- function(nt = 'ACGT', brackets = TRUE, arrows = TRUE){

  nt2 <- strsplit(nt, split='')[[1]]
  pyr <- nt2[nt2 %in% c('C', 'T')]
  w <- expand.grid(nt2, pyr, stringsAsFactors = FALSE)
  w <- w[,c(2,1)]
  w <- w[w[, 1]!=w[,2],]
  sp <- ifelse(arrows, '>', '')
  wx <- apply(w, 1, function(x){paste(c(x[1], sp, x[2]),collapse='')})

  z <- expand.grid(nt2, nt2, wx, stringsAsFactors = FALSE)
  z <- z[, c(2, 3, 1)]
  if(brackets) sp <- c('[',']')
  else sp <- c('','')
  w <- apply(z, 1, function(x){paste(c(x[1], sp[1], x[2], sp[2], x[3]), collapse = '')})
  names(w) <- NULL
  return(w)
}

#' Dinucleotide labels
#' 
#' @export
dinucleotides <- function(nt = 'ACGT'){
  
  nt2 <- strsplit(nt, split='')[[1]]
  src <- c('AC','AT','CC','CG','CT','GC','TA','TC','TG','TT') # source dinucleotide
  dbs <- NULL
  for(i in seq_along(src)){
    si <- src[i]
    sn <- strsplit(si,split='')[[1]]
    for(x in nt2[nt2!=sn[1]]) for(y in nt2[nt2!=sn[2]]){
      tgt <- c(x,y)
      sn2 <- rcmp(sn)
      tg2 <- rcmp(tgt)
      db <- paste(c(si,'>',tgt),collapse='')
      db2 <- paste(c(sn2,'>',tg2),collapse='')
      if(!db %in% dbs & !db2 %in% dbs){
        if(i %in% c(4,7)) dbs <- c(dbs, db2)
        else dbs <- c(dbs, db)
      }
    }
  }
  return(dbs)
}

rcmp <- function(x){
  
  w <- x
  w[x=='A'] <- 'T'
  w[x=='C'] <- 'G'
  w[x=='G'] <- 'C'
  w[x=='T'] <- 'A'
  
  return(rev(w))
}
#' 
#' Plot exposure
#'
#' Display barplot of exposure extracted for a specific sample
#'
#' @param object Object of class \code{tempoSig}
#' @param sample.id Sample index or name (\code{Tumor_Sample_Barcode}) to display
#' @param cutoff Minimum proportion for displaying signature labels
#' @param ... Other parameters to \code{barplot}
#' @return None
#' @export
plotExposure <- function(object, sample.id, cutoff = 1e-3, ...){

  if(!is(object, 'tempoSig')) stop('Object is not of class tempoSig')
  sname <- names(tmb(object))
  if(is.character(sample.id)){
    sample.id <- which(sname == sample.id)
    if(length(sample.id)==0) stop(paste0(sample.id, 'is not in object'))
  }
  sample.id <- as.integer(sample.id)
  expo <- expos(object)
  if(sample.id < 1 | sample.id > NROW(expo)) stop('sample.id out of bound in object')
  e <- expo[sample.id,]
  e <- e[e >= cutoff]
  names.arg <- names(e)
  names.arg[e < cutoff] <- ''
  graphics::barplot(e, main = sname[sample.id], las=2, names.arg = names.arg,
                    ylab = 'Proportions', ...)

  return(invisible(e))
}

#' Write Exposure
#'
#' Save a text output of exposures
#'
#' Writes a text file of specified name.
#'
#' @param object Object of class \code{tempoSig}
#' @param output File name of the output
#' @param sep Delimiter, either space or tab.
#' @param rm.na Remove rows with NAs (mutation load below minimum)
#' @param pv.out File name for p-value output. If \code{NULL}, \code{output}
#'        file is written with alternating observed and p-value columns.
#' @param cBio.format File output in cBioPortal \code{Generic Assay} format; 
#'        only works with \code{pv.out != NULL}
#'
#' @export
writeExposure <- function(object, output, sep = '\t', rm.na = FALSE, pv.out = NULL,
                          cBio.format = FALSE){

  if(!is(object, 'tempoSig')) stop('Object is not of class tempoSig')
  if(!is.character(output)) stop('Output file name must be characters')
  if(!sep %in% c(' ','\t')) stop('Delimiter must be either space or tab')
  expo <- expos(object)
  if(all(dim(expo) == 0)) stop('Exposure in object empty')
  if(cBio.format & is.null(pv.out)) stop('cBio.format requires pv.out')
 
  bad <- apply(expo, 1, function(x){all(is.na(x))})
  if(rm.na){
    if(sum(!bad)==0) stop('All samples are NA and rm.na = TRUE')
    expo <- expo[!bad, , drop = FALSE]
    tmba <- tmb(object)[!bad]
  } else
    tmba <- tmb(object)

  is.pv <- !all(dim(pvalue(object)) == 0)   # pvalue is not empty
  out0 <- data.frame(Tumor_Sample_Barcode = rownames(expo), TMB = tmba)
  
  if(!is.pv | !is.null(pv.out))  # no pvalue or separate output
    out <- cbind(out0, as.data.frame(expo))
  else out <- out0
  
  if(is.pv){
    if(!is.null(pv.out)) pout <- out0
    pv <- pvalue(object)
    if(rm.na) pv <- pv[!bad, , drop = FALSE]
    sig.names <- colnames(expo)
    for(k in seq(NCOL(expo))){
      if(is.null(pv.out)){
        tmp <- data.frame(expo[,k], pv[,k])
        names(tmp) <- paste0(sig.names[k], c('.observed','.pvalue'))
        out <- cbind(out, tmp)
      } else{
        tmp <- data.frame(pv[,k])
        names(tmp) <- sig.names[k]
        pout <- cbind(pout, tmp)
      }
    }
  }
  
  if(!cBio.format){
    colnames(out)[1:2] <- c('Sample Name', 'Number of Mutations') # compatibility
    if(!is.null(pv.out)) colnames(pout)[1:2] <- colnames(out)[1:2]
  } else{
    if(sum(is.na(rownames(out)))) 
      rownames(out) <- out[,2]
    out <- out[,-2, drop = FALSE]   # remove no. of mutation column
    if(colnames(out)[2]=='Signature.1')  # v2
      annot <- read.csv(system.file('extdata', 'msig_cBioPortal_v2.csv', package = 'tempoSig'))
    else  # v3
      annot <- read.csv(system.file('extdata', 'msig_cBioPortal_v3.csv', package = 'tempoSig'))
    idx <- match(colnames(out)[-1], annot[,1])
    out <- cbind(data.frame(
            ENTITY_STABLE_ID = paste('mutational_signature_contribution', annot[,1], sep='_'),
            NAME = annot[,2], 
            DESCRIPTION = annot$Description,
            URL = annot$URL), t(as.matrix(out[,-1]))[idx,])
    if(exists('pout')){
      if(sum(is.na(rownames(pout)))) 
        rownames(pout) <- pout[,2]
      pout <- pout[,-2, drop = FALSE]   # remove no. of mutation column
      pout <- cbind(data.frame(
        ENTITY_STABLE_ID = paste('mutational_signature_pvalue', annot[,1], sep='_'),
        NAME = annot[,2], 
        DESCRIPTION = annot$Description,
        URL = annot$URL), t(as.matrix(pout[,-1]))[idx,])
    }
  }
  
  write.table(out, file = output, sep = sep, row.names = F, quote = F)
  if(!is.null(pv.out)) write.table(pout, file = pv.out, sep = sep, row.names = F,
                                   quote = F)
  return(invisible(object))
}

#' Generate Mutation Catalog from MAF file
#' 
#' Input is MAF file and the corresponding trinucleotide catalog matrix is generated
#' 
#' @param maf MAF file name. It must contain a column named \code{Ref_Tri} 
#'        containing the trinucleotide sequences surrounding the mutation site.
#'        If the mutation site reference allele is \code{A, G}, the \code{Ref_Tri}
#'        is the complement sequence of the trinucleotides, such that its central
#'        allele is always \code{C, T}.
#'        
#' @return Count matrix with mutation contexts in rows and \code{Tumor_Sample_Barcode}
#'         in columns.
#' @export
maf2cat <- function(maf){
  
  if(!file.exists(maf)) stop(paste0('File ', maf, ' does not exist'))
  x <- data.table::fread(maf)
  x <- as.data.frame(x)
  col <- colnames(x)
  if(!'Ref_Tri' %in% col) stop('Column Ref_Tri does not exist in MAF')
  if('End_position' %in% col){
    col[col=='End_position'] <- 'End_Position'
    colnames(x) <- col
  } 
  x <- x[x$Variant_Type == 'SNP', 
         c('Tumor_Sample_Barcode','Chromosome', 'Start_Position', 'End_Position',
           'Reference_Allele', 'Tumor_Seq_Allele2', 'Ref_Tri')] 
  x <- x[!duplicated(x) & x$Ref_Tri != '',]
  
  mut <- rep('', NROW(x))
  if(NROW(x) > 0){
    for(i in seq(NROW(x))){
       w <- c(t(x[i,c('Reference_Allele', 'Tumor_Seq_Allele2')]), 
            strsplit(as.character(x[i, 'Ref_Tri']), split='')[[1]])
       if(w[1] %in% c('A','G')) 
         w[1:2] <- ntdag(w[1:2])  # Ref_Tri is already pyrimidine at the center
       mut[i] <- paste(c(w[3], '[', w[1], '>', w[2], ']', w[5]), collapse='')
    }
    mut <- factor(mut, levels=trinucleotides(), ordered = TRUE)
    tmut <- table(mut, x$Tumor_Sample_Barcode)
    tmut <- as.data.frame.matrix(tmut)
  } else{
    tmut <- data.frame(na=rep(0, 96))
    rownames(tmut) <- trinucleotides()
  }
  
  return(tmut)
}

# nucleotide complement
ntdag <- function(nt){
  
  z <- nt
  for(i in seq_along(nt)){
    if(nt[i]=='A') z[i] <- 'T'
    else if(nt[i]=='T') z[i] <- 'A'
    else if(nt[i]=='G') z[i] <- 'C'
    else if(nt[i]=='C') z[i] <- 'G'
    else stop('Unknown nucleotide in maf file')
  }
  return(z)
}

#' True and false positive rates
#' 
#' From supplied exposure prediction and actual vectors, compute 
#' true and false positive rates
#' @param xhat Predicted exposure vector
#' @param x True exposure vector
#' @param pvalue Vector of prediction p-values
#' @param alpha False positive rate threshold
#' @return list of vectors \code{tp} (true positives), \code{fp} (false positives),
#'         all positives \code{positives} and negatives \code{negatives} in
#'         names of \code{xhat}
#' @export
senspec <- function(xhat, x, pvalue = NULL, alpha = 0.05){
  
  if(is.null(names(xhat)) | is.null(names(x)))
    stop('Input vectors must have names')
  if(!is.null(pvalue)){ 
    if(sum(is.null(names(pvalue))) > 0) stop('pvalues must have names')
    if(length(xhat) != length(pvalue)) stop('xhat and pvalue have different lengths')
    if(!all(names(xhat)==names(pvalue))) stop('xhat and pvalue names mismatch')
  }

  sig <- union(names(xhat), names(x))
  vsig <- rep(0, length(sig))
  names(vsig) <- sig
  x <- vectorPad(x, vsig, value=0)
  xhat <- vectorPad(xhat, vsig, value=0)
  if(!is.null(pvalue)) pvalue <- vectorPad(pvalue, vsig, value=1)

  bhat <- xhat > 0
  if(!is.null(pvalue))           # filter with pvalues for significant subset
    bhat <- bhat & (pvalue <= alpha)
  b <- x > 0
# tpr <- sum(bhat & b) / sum(b)  # true positive rate
# fpr <- sum(bhat & !b) /sum(!b) # false positive rate
  tp <- names(bhat)[bhat & b]
  fp <- names(bhat)[bhat & !b]
  positives <- names(bhat)[b]
  negatives <- names(bhat)[!b]
  
  return(list(tp=tp, fp=fp, positives=positives, negatives=negatives))
}

# Expand named vector x to match xref names and order
vectorPad <- function(x, xref, value = 0){
  
  x2 <- rep(value, length(xref))
  names(x2) <- names(xref)
  x2[names(x)] <- x
  return(x2[match(names(xref), names(x2))])
}