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
; PIPELINE ARGUMENT: Name="CalibrationFile" Type="String" CalFileType="polcal" Default="AUTOMATIC" Desc="Filename of the desired polarization calibration file to be read"
; PIPELINE ARGUMENT: Name="Save" Type="int" Range="[0,1]" Default="1"
; PIPELINE COMMENT: Generate polarization model file from a flat field image.
; PIPELINE CATEGORY: Calibration
;
; HISTORY:
;   2017-02-22 MPF: Began based on gpi_measure_polarization_spot_calibration
;-

function gpi_generate_polarization_spot_model,  DataSet, Modules, Backbone

primitive_version = '$Id$' ; get version from subversion to store in header history
calfiletype = 'polcal' ; for loading polcal file, necessary for computing spot model
@__start_primitive

  im = *(dataset.currframe[0]) 
  szim = size(im)
  indq = *(dataset.currDQ[0])
  im_std = *(dataset.curruncert[0])
    
  obstype = backbone -> get_keyword('OBSTYPE')
  ifsfilter = gpi_simplify_keyword_value(backbone -> get_keyword('IFSFILT', count = ct))
  mode = backbone -> get_keyword('DISPERSR', count = ct)

  ;; verify image is a POL mode FLAT FIELD. 
  if ~strmatch(mode, '*wollaston*', /fold_case) then $
     return, error('FAILURE ('+functionName+'): Invalid input -- a POLARIMETRY mode file is required.') 
  if (~strmatch(obstype, '*arc*', /fold_case)) && $
     (~strmatch(obstype, '*flat*', /fold_case)) then $
        return, error('FAILURE ('+functionName+'): Invalid input -- The OBSTYPE keyword does not mark this data as a FLAT or ARC image.') 

  Backbone -> Log, "Using polarimetry cal file "+c_file, depth = 3

  ;; output filename for model
  suffix = "-"+strcompress(ifsfilter, /REMOVE_ALL)+'-polspotmodel'

  ;; start Python logging
  logging = Python.Import('logging')
  level = 10;logging.DEBUG
  format = '%(asctime)s %(name)-12s: %(levelname)-8s %(message)s'
  void = logging.basicConfig(format = format)
  logger = logging.getLogger()
  setLevel = Python.getattr(logger, 'setLevel')
  ;void = setLevel(10);level)


  ;; execute Python code for model generation
  gpi = Python.Import('gpi')
  output = gpi.gpi_pipeline_generate_spot_model(c_file, im, indq, im_std)
  offsets = output[0]
  other = output[1]
  zernikes = output[2]


  ;; Set keywords for outputting files into the Calibrations DB
  backbone -> set_keyword, "FILETYPE", "Polarimetry Spot Model Cal File"
  backbone -> set_keyword,  "ISCALIB", "YES", 'This is a reduced calibration file of some type.'
    
  backbone -> set_keyword, "HISTORY", "      ", ext_num = 0
  ;; FIXME  descriptive history
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


  if ( Modules[thisModuleIndex].Save eq 1 ) then begin
    b_Stat = save_currdata( DataSet,  Modules[thisModuleIndex].OutputDir, suffix, display = 0, $
                            savedata = offsets,  output_filename = out_filename)
    if ( b_Stat ne OK ) then  return, error ('FAILURE ('+functionName+'): Failed to save dataset.')

    writefits, out_filename, other, /append
    writefits, out_filename, zernikes, /append
  endif

  *(dataset.currframe[0]) = offsets
  if tag_exist( Modules[thisModuleIndex], "stopidl") then if keyword_set( Modules[thisModuleIndex].stopidl) then stop

  return, ok

end
