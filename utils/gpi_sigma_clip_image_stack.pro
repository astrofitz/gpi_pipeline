;+
; NAME: gpi_sigma_clip_image_stack 
;	Implement image combination via sigma clipping
;
; INPUTS:
; KEYWORDS:
; OUTPUTS:
;
; HISTORY:
;	Began 013-12-15 01:24:25 by Marshall Perrin 
;-


function gpi_sigma_clip_image_stack, stack_in, sigma_threshold=sigma_threshold, parallelize=parallelize, im_sig=im_sig

	if ~(keyword_set(sigma_threshold)) then sigma_threshold=3

	sz = size(stack_in)
	if sz[0] ne 3 then return, error("Input has wrong dimensionality. Must be 3d cube.")
	im_mean=dblarr(sz[1],sz[2])
	im_sig=dblarr(sz[1],sz[2])

	if ~(keyword_set(parallelize)) then begin
		; iterate over all pixels to call resistant_mean
		for i=0, sz[1]-1 do begin
			for j=0, sz[2]-1 do begin
				resistant_mean, stack_in[i,j,*], sigma_threshold, meanval, sigval
                                im_mean[i, j] = meanval
                                im_sig[i, j] = sigval
			endfor
		endfor
	endif else begin
		numsplit=!CPU.TPOOL_NTHREADS
		; run this in parallel
		gpi_split_for, 0,sz[1]-1, nsplit=numsplit, $
			varnames=['stack_in','sigma_threshold','im_mean','im_sig', 'sz'], $
			outvar=['im_mean', 'im_sig'],$
			commands=[	'for j=0, sz[2]-1 do begin',$
						'   resistant_mean, stack_in[i,j,*], sigma_threshold, meanval, sigval',$
						'   im_mean[i,j] = meanval',$
						'   im_sig[i,j] = sigval',$
						'endfor']
		; merge results
		for k=0,numsplit-1 do begin
			tmpvar = scope_varfetch('im_mean'+strc(k))
			im_mean+=tmpvar
			tmpvar = scope_varfetch('im_sig'+strc(k))
			im_sig+=tmpvar
		endfor



	endelse
	return, im_mean
end
