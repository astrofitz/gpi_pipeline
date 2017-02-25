;+
; NAME: gpi_generate_polarization_spot_model
; PIPELINE PRIMITIVE DESCRIPTION: Generate Polarization Spot Model
;
;    gpi_generate_polarization_spot_model models the appearance of
;    polarized spots using a 2D image based on flat field
;    observations.
;
; ALGORITHM:
;
;
; INPUTS: 2D image from flat field in polarization mode, Measured polarization spot locations calibration file
; OUTPUTS: polarization spot model calibration file
;
; PIPELINE ORDER: 1.9
; PIPELINE ARGUMENT: Name="Save" Type="int" Range="[0,1]" Default="1"
; PIPELINE COMMENT: Generate polarization model file from a flat field image.
; PIPELINE CATEGORY: Calibration
;
; HISTORY:
;   2017-02-22 MPF: Began based on gpi_measure_polarization_spot_calibration
;-

function gpi_generate_polarization_spot_model,  DataSet, Modules, Backbone

primitive_version= '$Id$' ; get version from subversion to store in header history
@__start_primitive

    im=*(dataset.currframe[0]) 
    
    obstype=backbone->get_keyword('OBSTYPE')
	ifsfilter=gpi_simplify_keyword_value(backbone->get_keyword('IFSFILT', count=ct))
	mode=backbone->get_keyword('DISPERSR', count=ct)

    ; verify image is a POL mode FLAT FIELD. 
    if ~strmatch(mode,'*wollaston*',/fold_case)  then return, error('FAILURE ('+functionName+'): Invalid input -- a POLARIMETRY mode file is required.') 
    if(~strmatch(obstype,'*arc*',/fold_case)) && (~strmatch(obstype,'*flat*',/fold_case)) then $
        return, error('FAILURE ('+functionName+'): Invalid input -- The OBSTYPE keyword does not mark this data as a FLAT or ARC image.') 
    

    szim=size(im)

    return, error("Not implemented yet!")





    
    
    suffix="-"+strcompress(ifsfilter,/REMOVE_ALL)+'-polspotmodel'
    fname = file_basename(filename, ".fits")+suffix+'.fits'
    
    ; Set keywords for outputting files into the Calibrations DB
    backbone->set_keyword, "FILETYPE", "Polarimetry Spot Model Cal File"
    backbone->set_keyword,  "ISCALIB", "YES", 'This is a reduced calibration file of some type.'
    
	backbone->set_keyword, "HISTORY", "      ",ext_num=0
    ;; backbone->set_keyword, "HISTORY", " Pol Calib File Format:",ext_num=0
    ;; backbone->set_keyword, "HISTORY", "    Axis 1:  pos_x, pos_y, rotangle, width_x, width_y",ext_num=0
    ;; backbone->set_keyword, "HISTORY", "       rotangle is in degrees, widths in pixels",ext_num=0
    ;; backbone->set_keyword, "HISTORY", "    Axis 2:  Lenslet X",ext_num=0
    ;; backbone->set_keyword, "HISTORY", "    Axis 3:  Lenslet Y",ext_num=0
    ;; backbone->set_keyword, "HISTORY", "    Axis 4:  Polarization ( -- or | ) ",ext_num=0
	;; backbone->set_keyword, "HISTORY", "      ",ext_num=0
    
    
    

;@__end_primitive
; - NO - 
; due to special output requirements (outputting pixels lists, not anything in
; the *dataset.currframe structure as usual)
; we can't use the standardized template end-of-procedure file saving code here.
; Instead do it this way: 

        ;; TEMP
;; if ( Modules[thisModuleIndex].Save eq 1 ) then begin
;; 	b_Stat = save_currdata( DataSet,  Modules[thisModuleIndex].OutputDir, suffix, display=0 ,$
;; 		   savedata=spotpos,  output_filename=out_filename)
;;     if ( b_Stat ne OK ) then  return, error ('FAILURE ('+functionName+'): Failed to save dataset.')

;;     writefits, out_filename, spotpos_pixels, /append
;;     writefits, out_filename, spotpos_pixvals, /append
;; end

;; *(dataset.currframe[0])=spotpos
;; if tag_exist( Modules[thisModuleIndex], "stopidl") then if keyword_set( Modules[thisModuleIndex].stopidl) then stop

return, ok

end