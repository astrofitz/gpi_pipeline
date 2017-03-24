;+
; NAME: gpi_load_polarimetry_spot_model_calibration
; PIPELINE PRIMITIVE DESCRIPTION: Load Polarimetry Spot Model Calibration
;
;   Reads a polarimetry spot model calibration file from disk.
;   The spot model calibration is stored using pointers into the common block.
;
; INPUTS: Not used directly
; OUTPUTS: none; polarimetry spotmodel cal file is loaded into memory
;
; PIPELINE COMMENT: Reads a pol spot model calibration file from disk. This primitive is required for polarimetry data-cube extraction using the MODEL method.
; PIPELINE ARGUMENT: Name="CalibrationFile" Type="String" CalFileType="polspotmodel" Default="AUTOMATIC" Desc="Filename of the desired polarimetry spot model calibration file to be read"
; PIPELINE ORDER: 0.52
; PIPELINE CATEGORY: PolarimetricScience,Calibration
;
; HISTORY:
;   2017-03-24 MPF: Adapted from gpi_load_polarimetry_spot_calibration
;-

function gpi_load_polarimetry_spot_model_calibration, DataSet, Modules, Backbone

primitive_version= '$Id$' ; get version from subversion to store in header history
calfiletype = 'polspotmodel'
@__start_primitive

  ;need_to_load=1

  ; Lesson learned: we can't avoid reloading the wavecal each time, because we
  ; may end up shifting it due to flexure. So  this is a false economy
  
;	; Check common block for already loaded calibration information
;    if keyword_set(polcal) then if tag_exist(polcal, 'filename') then if polcal.filename eq c_file then begin
;        backbone->Log, "Requested pol cal file is already loaded, no need to load again.", depth=3
;        backbone->Log, c_File
;        need_to_load=0
;    endif
;
;

    ;if need_to_load then begin

	fits_info, c_file, n_ext=numext, /silent
	Backbone->Log, "Loading polarimetry spot model offset data",depth=3
	polspotmodel_offsets = readfits(c_File, header,ext=numext-2,/silent)

	Backbone->Log, "Loading polarimetry spot model other data",depth = 3
	polspotmodel_other = readfits(c_File, ext=numext-1,/silent)

	Backbone->Log, "Loading polarimetry spot model zernike",depth = 3
	polspotmodel_zernikes = readfits(c_File, ext=numext,/silent)
	
	polspotmodel={iffsets:polspotmodel_offsets, other:polspotmodel_other, zernikes:polspotmodel_zernikes, filename:c_File}

    ;endif

    backbone->set_keyword, "HISTORY", functionname+": Read calibration file",ext_num=0
    backbone->set_keyword, "HISTORY", functionname+": "+c_File,ext_num=0
    backbone->set_keyword, "DRPPOLSC", c_File, "DRP pol spot model calibration file used.", ext_num=0
    
    void=mrdfits(c_file, 0, headerphu, /silent)
    object=sxpar(headerphu, 'OBJECT')
    
    if strcmp(object,'TEL_SIM') then begin ;If using the telescope simulator use some basic options. 
      wc_elev=0
      wc_inport='perfect' ;J
    endif else begin
      ;get elevation amd port for flexure effect correction
      wc_elev = sxpar(  Header, 'ELEVATIO', count=count) 
      if count eq 0 then begin
        void=mrdfits(c_File, 0, headerphu,/silent)
        wc_elev = sxpar(  headerphu, 'ELEVATIO', count=count)
      endif
    
      wc_inport = sxpar(  Header, 'INPORT', count=count) 
      if count eq 0 then begin
        void=mrdfits(c_File, 0, headerphu,/silent)
        wc_inport= sxpar(  headerphu, 'INPORT', count=count)
      endif      
    endelse
    
    wc_date = sxpar(  Header, 'DATE-OBS', count=count) 
    if count eq 0 then begin
      void=mrdfits(c_File, 0, headerphu,/silent)
      wc_date= sxpar(  headerphu, 'DATE-OBS', count=count)
    endif
    
    backbone->set_keyword, "WVELEV", wc_elev, "Wavelength solution elevation", ext_num=0
    backbone->set_keyword, "WVPORT", wc_inport, "Wavelength solution inport", ext_num=0
    backbone->set_keyword, "WVDATE", wc_date, "Wavelength solution obstime", ext_num=0

@__end_primitive 

end
