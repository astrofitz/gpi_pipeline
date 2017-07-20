;+
; NAME: gpi_estimate_2d_uncertainty
; PIPELINE PRIMITIVE DESCRIPTION: Estimate 2d uncertainty image
;
; OUTPUTS: The data is modified in memory to add the uncertainty. The file on disk is NOT changed. 
;
; PIPELINE COMMENT: Estimate the 2d uncertainty image.
; PIPELINE ORDER: 0.1
; PIPELINE CATEGORY: Calibration
;
; HISTORY:
;  2017-07-20  MPF  started
;-

function gpi_estimate_2d_uncertainty,  DataSet, Modules, Backbone

primitive_version= '$Id$' ; get version from subversion to store in header history
@__start_primitive

  ;; should happen early on, still in raw image


  ;; load data and compute uncertainty image
  im = *(dataset.currframe[0]) 
  im_std = gpi_estimate_2d_uncertainty_image(im, *dataset.headersPHU[0], *dataset.headersExt[0])

  ;; set current uncertainty frame
  if ptr_valid(dataset.curruncert) eq 1 then begin
    ;; warn if already exists
    *dataset.curruncert = im_std
  endif else begin
    dataset.curruncert = ptr_new(im_std)
  endelse
  
  logstr = 'estimated 2d uncertainty image'
  backbone -> set_keyword, "HISTORY", logstr, ext_num = 0
  backbone -> Log, logstr

@__end_primitive
end
