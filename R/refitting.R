#' Refit spectra using MutationalCone
#' 
#' Given input spectra, find proportions of known signatures
#' 
#' Adopted from Omichessan et al. 
#' \url{http://dx.doi.org/10.1371/journal.pone.0221235}.
#' 
#' @param catalog Input matrix of dimension \code{(M, N)}, where
#'        \code{M} is the no. of genetic features, e.g., 96 for SNV trinucleotides)
#'        and \code{N} is the number of samples to refit
#' @param signatures Matrix of dimension \code{(M,K)} with \code{K} reference 
#'        signatures in columns (e.g., COSMIC signatures).
#' @param normalize Normalize output column-wise
#' @return Matrix of dimension \code{(K, N)} with columns giving estimated
#'         loading of signatures in each sample.
#' @export
mutationalCone <- function(catalog, signatures='cosmic_v3', normalize=FALSE){
  
  if(is.character(signatures)){
    if(signatures=='cosmic_v3'){
      fl <- system.file('extdata/cosmic_sigProfiler_SBS_signatures.txt', package = 'tempoSig')
      signatures <- as.matrix(read.table(file =fl, header = TRUE, sep = '\t'))
    }
  } else if(!is.matrix(signatures)) stop('Input signature not a matrix')
  
  if(sum(is.na(rownames(catalog))) > 0) stop('Rows of catalog must be named')
  if(NROW(catalog)!=NROW(signatures)) 
    stop('Dimension of catalog does not match signature')
  idx <- match(rownames(signatures), rownames(catalog))
  if(sum(is.na(idx)) > 0) stop('Row names of catalog do not match signature')
  catalog <- as.matrix(catalog[idx, , drop = FALSE])
  
  # Orthonormalization of the subspace generated by reference signatures 
  S <- signatures 
  S.qr <- qr(S)
  Q <- qr.Q(S.qr) # orthonormal basis of the subspace
  R <- qr.R(S.qr) # components of the reference signatures in the orthonormal basis
  
  # Projection of the catalogue onto the subspace generated by
  # reference signatures 
  proj.subspace <- t(Q) %*% catalog
  
  # Projection onto the cone spanned by the signatures
#  weights <- as.vector(coneproj::coneB(y = as.vector(proj.subspace),
#                                       delta = R)$coefs)
  weights <- apply(proj.subspace, MARGIN=2, 
                   FUN=function(x){ 
                     as.vector(coneproj::coneB(y = as.vector(x), delta = R)$coefs)
                   })
  
  rownames(weights) <- colnames(signatures)
  colnames(weights) <- colnames(catalog)
  if(normalize) weights <- t(t(weights)/colSums(weights))
  if(NCOL(weights)==1) weights <- weights[,1]
  
  return(weights)
}

#' Cosine similarity
#' 
#' Row names of two data matrices (mutation contexts) are used for comparison.
#' If the row names do not match completely, the larger set is used as reference 
#' with the smaller set expanded with zero-padding.
#' 
#' @param A Test matrix of dimension \code{(m,a)} 
#' @param B Reference matrix of dimension \code{(m, b)}
#' @param diag Only compare column \code{A[, i]} with column \code{B[, i]} 
#'        where \code{i=1, ..., ncol(A)=ncol(B)}.
#' @return If \code{diag = TRUE}, vector of overlap between columns of \code{A}
#'         and columns of \code{B} in one-to-one mapping; if \code{diag = FALSE},
#'         matrix of dimension \code{(a,b)}, whose elements give overlap of column 
#'         \code{a} in matrix \code{A} with column \code{b} in matrix \code{B}.
#' @export
cosineSimilarity <- function(A, B, diag = FALSE){
  
  if(!is.matrix(A)) A <- as.matrix(A)
  if(!is.matrix(B)) B <- as.matrix(B)
  a <- NCOL(A)
  b <- NCOL(B)
  if(diag & a != b) stop('diag requires same dimension of A and B')
  
  if(diag){ 
    cos <- rep(0, a)
    names(cos) <- colnames(A)
  } else{ 
    cos <- matrix(0, nrow=a, ncol=b)
    rownames(cos) <- colnames(A)
    colnames(cos) <- colnames(B)
  }
    
  for(i in seq(1,a)) for(j in seq(1,b)){
    if(diag & i!=j) next()
    xa <- A[,i]
    xb <- B[,j]
    if(length(xa) < length(xb)){
      xtest <- xa
      xref <- xb
    } else{
      xtest <- xb
      xref <- xa
    }
    xtest2 <- rep(0, length(xref))
    names(xtest2) <- names(xref)
    if(sum(is.na(names(xtest)) > 0) | 
       sum(!names(xtest) %in% names(xref)) > 0) stop('Names mismatch')
    xtest2[names(xtest)] <- xtest
    if(sum(xtest2)==0 | sum(xref)==0) x <- 0
    else x <- sum(xtest2*xref) / sqrt(sum(xtest2^2) * sum(xref^2))
    if(diag) cos[i] <- x
    else cos[i,j] <- x
  }
  return(cos)
}