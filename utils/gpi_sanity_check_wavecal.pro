;+
; NAME:  gpi_sanity_check_wavecal
;	Utility function to do some basic quality tests on a wavecal.
;
;	Passing these checks is probably a necessary but far from
;	sufficient condition for a wavecal to be of good quality.
;
;	Currently implemented checks include:
;		- basic file dimensionality
;		- comparison of X- and Y-shifts between adjacent lenslets
;		  to check for entire rows that "jump" out of position, which
;		  is a common problem for the original barycenter wavecal algorithm
;
; INPUTS: 
;	filename_or_cal_data	Either the filename of a wavecal file,
;							or the 3D datacube array of the wavecal itself. 
;	
; KEYWORDS:
;	/silent		don't print any info to the screen
;	/noplots	don't make any diagnostic plots
;	/all		Check all wavecals in current directory and return results
;				as an array.
;
;	errmsg		Output keyword giving informative description of failure,
;				if one occurs. 
;	charsize	Font size for labeling the plots
;	repair		Try to repair if this file is bad. (EXPERIMENTAL!)
; OUTPUTS: 
;	1 if sanity checks pass OK, 0 if failed
;
; HISTORY:
;	Began 013-10-02 21:43:05 by Marshall Perrin 
;-


function gpi_sanity_check_wavecal, filename_or_cal_data, silent=silent, $
	noplots=noplots,all=all, threshold=threshold, charsize=charsize, errmsg=errmsg, $
	repair=repair,stop=stop


	if ~(keyword_set(charsize)) then charsize=2 ; larger for the small plots

	; check files in this directory option
	if keyword_set(all) then begin
		files = file_search('*wavecal.fits')
		results= bytarr(n_elements(files))
	    for i=0L,n_elements(files)-1 do begin
			results[i] = gpi_sanity_check_wavecal(files[i])
			if ~(keyword_set(noplots)) then stop ; let the user see each plot
		endfor
		return, results
	end


	; check a single file/datacube option:
	if size(filename_or_cal_data,/TNAME) eq 'STRING' then begin
		; user supplied a filename
		filename = filename_or_cal_data
		loaded_from = 'file'

		if ~file_test(filename) then begin
			errmsg = 'File '+filename+" does not exist."
			if ~(keyword_set(silent)) then message,/info, errmsg
			return, 0
		endif
		;prihdr = headfits(filename,ext=0,/silent)
		data = readfits(filename, ext=1, exthdr,/silent)
	endif else begin
		; username supplied an array
		loaded_from = 'array'
		data = filename_or_cal_data 
		filename = 'The supplied wavecal datacube '

	endelse


	sz = size(data)
	if sz[0] ne 3 then begin
		errmsg = filename+" is invalid. Not a 3D datacube."
		if ~(keyword_set(silent)) then message,/info,errmsg
		return, 0
	endif

	loadct,0,/silent
	; Check histogram of X delta values

	xdiff = data[*,*,0] - shift(data[*,*,0],1)
	ydiff = data[*,*,1] - shift(data[*,*,1],1)
	dispdiff = data[*,*,3] - shift(data[*,*,3],1)
	thetadiff = data[*,*,4] - shift(data[*,*,4],1)
	wg = where(finite(xdiff) and finite(ydiff))
	pct_wide_x = total( abs(xdiff[wg]-mean(xdiff[wg]) ) gt 2 ) / n_elements(wg)
	pct_wide_y = total( abs(ydiff[wg]-mean(ydiff[wg]) ) gt 2 ) / n_elements(wg)


	; Check for a case of all xdiffs being the same. This is both indicative of
	; a totally bogus file (for instance all 0s or nans if the creating script
	; crashed somehow) and also, would if not caught ahead of time cause the
	; plothist commands below to crash and potentially lock the pipeline.
	n_xd =  n_elements(uniqvals(xdiff[wg]))
	if n_xd eq 1 then begin
		errmsg = filename+" looks invalid. All x pixel diffs are exactly the same value instead of showing the variation across the detector."
		if ~(keyword_set(silent)) then message,/info, errmsg
		return, 0
	endif


	if ~(keyword_set(threshold)) then threshold=0.2
	; Fail
	if pct_wide_x*100 gt threshold or pct_wide_y*100 gt threshold then begin
		errmsg = filename+" looks invalid. Too many X and Y offsets between adjacent lenslets are outside expected values."
		if ~(keyword_set(silent)) then message,/info, errmsg
		valid = 0
	endif else valid = 1



	if ~(keyword_set(noplots)) then begin
		!y.omargin = [0,5]
		!p.multi=[0,2,3]


		plothist, xdiff[wg],bin=0.01,/ylog,title='Adjacent lenslet X diffs',$
			xtitle=sigfig(pct_wide_x*100,3)+"% outside mean +-2", charsize=charsize
		ver, mean(xdiff[wg],/nan),/line
		ver, mean(xdiff[wg],/nan)+2,/line, color=cgcolor('yellow')
		ver, mean(xdiff[wg],/nan)-2,/line, color=cgcolor('yellow')


		plothist, ydiff[wg],bin=0.01,/ylog,title='Adjacent lenslet Y diffs',$
			xtitle=sigfig(pct_wide_y*100,3)+"% outside mean +-2", charsize=charsize
		ver, mean(ydiff[wg],/nan),/line
		ver, mean(ydiff[wg],/nan)+2,/line, color=cgcolor('yellow')
		ver, mean(ydiff[wg],/nan)-2,/line, color=cgcolor('yellow')

		loadct,0
		sig = stddev(xdiff-mean(xdiff[wg]),/nan)
		imdisp, bytscl(xdiff-mean(xdiff[wg]),-3*sig, 3*sig),/noscale ,/axis,title='Variations in d(X0)/dx', charsize=charsize

		sig = stddev(ydiff-mean(ydiff[wg]),/nan)
		imdisp, bytscl(ydiff-mean(ydiff[wg]),-3*sig, 3*sig),/noscale ,/axis,title='Variations in d(Y0)/dx', charsize=charsize

		sig = stddev(dispdiff,/nan)
		imdisp, bytscl(dispdiff,-3*sig, 3*sig),/noscale ,/axis,title='Variations in d(dispersion)/dy', charsize=charsize

		sig = stddev(thetadiff,/nan)
		imdisp, bytscl(thetadiff,-3*sig, 3*sig),/noscale ,/axis,title='Variations in d(theta)/dx', charsize=charsize

		if valid then title_extra = ' looks good' else title_extra = ' FAILS QUALITY CHECK'
		cgtext, 0.5, 0.95,  ALIGNMENT=0.5, charsize=charsize, /normal, filename + title_extra

		!p.multi=0
		!y.omargin= 0
	endif



	if ~valid then begin
		if keyword_set(repair) then begin
			message,/info, 'Highly experimental wavecal interpolation repair code!!! '
			message,/info, '  Use at your own risk, results not guaranteed.'

			if loaded_from ne 'file' then message,'Can only repair if wavecal was loaded from filename.'

			badmask =   (abs(xdiff - median(xdiff[wg])) gt 1) or (abs(ydiff - median(ydiff[wg])) gt 1)
			wbad = where(badmask, badct)

			message,/info,'There are '+strc(total(badmask))+" lenslets that look suspicious."

			data0 = data
			for i=0,4 do begin
				vals = data[*,*,i]
				vals[wbad] = !values.f_nan
				;smoothed = smooth(median(vals,5),5,/nan)
				;vals[wbad] = smoothed[wbad]
				data[*,*,i] = vals
			endfor
	
	xdiff2 = data[*,*,0] - shift(data[*,*,0],1)
	ydiff2 = data[*,*,1] - shift(data[*,*,1],1)


			;inds = array_indices( vals, where(badmask))

			;data[reform(inds[0,*]), reform(inds[1,*]), *] = !values.f_nan

		
			priheader = headfits(filename,/silent)
			
			sxaddpar,priheader, 'HISTORY', 'gpi_sanity_check_wavecal: trying to repair/interpolate bad wavecal fits'

			outfn = strepex(filename, '.fits', '_repaired.fits')

			mwrfits, 0, outfn, priheader,/create
			mwrfits, data, outfn, extheader
			message,/info, 'Attempt at a repaired wavecal written to :'
			message,/info, '   '+outfn


		endif


		return, 0
	endif
	; Warn but don't fail

	if pct_wide_x*100 gt threshold/2 or pct_wide_y*100 gt threshold/2 then begin
		errmsg = filename+" looks possibly marginal. Many X and Y offsets between adjacent lenslets are outside expected values (more than halfway to the failure threshold."
	endif else begin
		errmsg = filename+" passes basic check." 
	endelse


	;stop

	if ~(keyword_set(silent)) then message,/info, errmsg

	if keyword_set(stop) then stop
	;atv, [[[xdiff-mean(xdiff[wg])]],[[ydiff-mean(ydiff[wg])]],[[dispdiff]],[[thetadiff]]],/bl

	return, 1


end
