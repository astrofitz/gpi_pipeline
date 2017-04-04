;+
; NAME: gpi_assemble_polarization_cube
; PIPELINE PRIMITIVE DESCRIPTION: Assemble Polarization Cube
;
;         extract polarization-mode data cube from an image
;        define first suffix '-podc' (polarization data-cube)
;
;        This routine transforms a 2D detector image in the dataset.currframe input
;        structure into a 3D data cube in the dataset.currframe output structure.
;        (not much of a data cube - really just 2x 2D images)
;
;
; ALGORITHM NOTES:
;
;    Ideally this should be done as an optimum weighting
;    (see e.g. Naylor et al, 1997 MNRAS)
;
;    That algorithm is as follows: For each lenslet spot,
;       -divide each pixel by the expected fraction of the total lenslet flux
;        in that pixel. (this makes each pixel an estimate of the total lenslet
;        flux)
;        -Combine these into a weighted average, weighted by the S/N per pixel
;
;
; INPUTS: detector image in polarimetry mode
; common needed: filter, wavcal, tilt, (nlens)
;
; OUTPUTS: Polarization pair datacube
;
; PIPELINE COMMENT: Extract 2 perpendicular polarizations from a 2D image.
; PIPELINE ARGUMENT: Name="Save" Type="int" Range="[0,1]" Default="0" Desc="1: save output on disk, 0: don't save"
; PIPELINE ARGUMENT: Name="gpitv" Type="int" Range="[0,500]" Default="2" Desc="1-500: choose gpitv session for displaying output, 0: no display "
; PIPELINE ARGUMENT: Name="Method" Type="String" Range="BOX|PSF|MODEL" Default="BOX" Desc="Method for pol cube reconstruction, simple box, Gaussian PSF, or forward model"
; PIPELINE ORDER: 2.0
; PIPELINE CATEGORY: PolarimetricScience, Calibration
;
; HISTORY:
;   2009-04-22 MDP: Created, based on DST's cubeextract_polarized.
;   2009-09-17  JM: added DRF parameters
;   2009-10-08  JM: add gpitv display
;   2010-10-19  JM: split HISTORY keyword if necessary
;   2011-07-15  MP: Code cleanup.
;   2011-06-07  JM: added FITS/MEF compatibility
;   2013-01-02  MP: Updated output file orientation to be consistent with
;		    spectral mode and raw data.
;   2013-07-17  MP: Renamed for consistency
;   2013-11-30  MP: Clear DQ and Uncert pointers
;   2014-02-03  MP: Code and docs cleanup
;   2014-07-01 MPF: Modified "PSF" extraction for weighting by a Gaussian
;                   and a noise map.
;   2017-02-22 MPF: Added forward-modeling extraction.
;-

function gpi_assemble_polarization_cube, DataSet, Modules, Backbone
  primitive_version= '$Id$' ; get version from subversion to store in header history
  
  @__start_primitive
  
  
  if tag_exist( Modules[thisModuleIndex], "method") then method=strupcase(Modules[thisModuleIndex].method) else method='BOX'
  if method eq '' then method='BOX'
  if method ne 'BOX' and method ne 'PSF' and method ne 'MODEL' then return, error("Not a valid method argument name: "+method)
  
  
  input=*dataset.currframe
  indq=*dataset.currDQ
  
  ;;filt = gpi_simplify_keyword_value(strc(backbone->get_keyword( "IFSFILT")))
  
  ;; Verify this is in fact polarization mode data
  mode= strc(backbone->get_keyword( "DISPERSR", count=ct))
  mode = strlowcase(mode)
  if ~strmatch(mode,"*wollaston*",/fold) then begin
    backbone->Log, "ERROR: That's not a polarimetry file!"
    return, not_ok
  endif
  
  ;; polarization spot locations come from the calibration file,
  ;; which must have been loaded already in readpolcal
  
  if ~(keyword_set(polcal.coords)) then return, error("You muse use Load Polarization Calibration before Assemble Polarization Cube")
  
  polspot_params=polcal.spotpos
  polspot_coords=polcal.coords
  polspot_pixvals=polcal.pixvals
  
  sz = size(polspot_coords)
  nx = sz[1+2]
  ny = sz[2+2]
  
  ;; errors
  badpix = indq GT 0
  
  im_uncert = gpi_estimate_2d_uncertainty_image(input, *dataset.headersPHU[numfile], *dataset.headersExt[numfile])


  polcube = fltarr(nx, ny, 2)+!values.f_nan
  dqcube = bytarr(nx, ny, 2)
  wpangle =  strc(backbone->get_keyword( "WPANGLE"))
  backbone->Log, "WP angle is "+strc(wpangle), depth=2
  
  mask = input*0   ; Mask array for which pixels are used when assembling the cube
  residual = input ; residual for observed-model difference when assembling the cube

  if method eq 'MODEL' then begin
    ;; turn on logging
    logging = Python.Import('logging')
    format = '%(asctime)s %(name)-12s: %(levelname)-8s %(message)s'
    void = logging.basicConfig(format = format)
    ;; Python.Run, 'logging.getLogger().setLevel(logging.DEBUG)'
    Python.Run, 'logging.getLogger().setLevel(logging.INFO)'

    ;; Extract using forward modeling
    gpi = Python.Import('gpi')
    output = gpi.gpi_pipeline_extract(input, im_uncert^2, indq, polspotmodel.offsets, polspotmodel.other, polspotmodel.zernikes, polcal.filename)
    polcube = output[0]
    dqcube = output[1]

  endif else begin              ; BOX or PSF
    indices, input, xx, yy
    ;;  Extract the data to a datacube
    for pol = 0, 1 do begin
      for ix = 0L, nx-1 do begin
        for iy = 0L, ny-1 do begin
          wg = where(finite(polspot_pixvals[*, ix, iy, pol]) and polspot_pixvals[*, ix, iy, pol] gt 0, gct)
          if gct eq 0 then continue
        
          spotx = polspot_coords[0, wg, ix, iy, pol] ; X coord of spot center
          spoty = polspot_coords[1, wg, ix, iy, pol] ; Y coord of spot center
        
          case method of
            'PSF': begin
              ;; Extract using a fixed saved PSF from the calibration data.
              ;; WARNING does not get updated with flexure properly.
              ;; NOTE  want to replace all of this with high res microlens PSF code!
          
              box_rad = 5       ; extraction box half-width
            
              ;; For each spot read in the best fit parameters  
              params = polspot_params[*, ix, iy, pol]
            
              ;; Set the upper and lower limits on the box that we're looking at
              if params[0] le 0+box_rad then lowx = 0 else lowx = uint(params[0]-box_rad)
              if params[0] ge 2048-box_rad then highx = 2047 else highx = uint(params[0]+box_rad)
              if params[1] le 0+box_rad then lowy = 0 else lowy = uint(params[1]-box_rad)
              if params[1] ge 2048-box_rad then highy = 2047 else highy = uint(params[1]+box_rad)
            
              ;; Reformat the parameters for the mpfit2peak functions
              fact = .35        ; factor for scaling gaussian width (?!)
              p = [0, 1., params[3]*fact, params[4]*fact, params[0]-lowx, params[1]-lowy, params[2]*!dtor]
            
              ;; Extract out area of interest
              in_box = input[lowx:highx, lowy:highy]
              unc_box = im_uncert[lowx:highx, lowy:highy]
              bp_box = badpix[lowx:highx, lowy:highy]
              ;; Get the x,y indices of each pixel
              indices, in_box, xx, yy
            
              ;; Calculate the "distance" U and a gaussian profile for the spot
              u = mpfit2dpeak_u(xx, yy, p, /tilt)
              g = mpfit2dpeak_gauss(xx, yy, p, /tilt)
            
              g /= total(g)

              ;; compute weights, with bad pixels zero weight
              w = (g^2/unc_box^2) * (1-bp_box)
            
              ;; Set a "distance" cutoff
              udist = 20.
              plist = where(u le udist, ct, complement = gtu)
              w[gtu] = 0

              ;; normalize the weights
              w /= total(w)
              ;; apply PSF fraction correction
              w /= g

              ;; fix any divides-by-zero
              w_nan = where(~finite(w), ct)
              if ct gt 0 then w[w_nan] = 0.

              ;; compute weighted sum
              polcube[ix, iy, pol] = total(in_box*w)/total(g*w)
              dqcube[ix, iy, pol] = total(bp_box, /preserve_type)
            
            end
            'BOX': begin
              ;; Extract using a 5 pixel box
              cenx = round(polcal.spotpos[0, ix, iy, pol])
              ceny =  round(polcal.spotpos[1, ix, iy, pol])
              boxsize = 2
              if cenx-boxsize lt 0 or ceny-boxsize lt 0 or cenx+boxsize gt 2047 or ceny+boxsize gt 2047 then break
            
              polcube[ix, iy, pol] = total(input[ cenx-boxsize:cenx+boxsize, ceny-boxsize:ceny+boxsize]  )
              dqcube[ix, iy, pol] = total(indq[cenx-boxsize:cenx+boxsize, ceny-boxsize:ceny+boxsize], /preserve_type)
              mask[cenx-boxsize:cenx+boxsize, ceny-boxsize:ceny+boxsize] += pol+1
              residual[cenx-boxsize:cenx+boxsize, ceny-boxsize:ceny+boxsize] = 0
            end
          endcase
        
          ;; Example for putting in a breakpoint here to examine why some
          ;; particular lenslet is going wrong:
          ;;if ix eq 130 and iy eq 148 and pol eq 1 then stop

        endfor
      endfor
    endfor
  endelse
  
  ;; Update FITS header
  
  ;; Update WCS with RA and Dec information As long as it's not a TEL_SIM image
  sz = size(polcube)
  if ~strcmp(string(backbone->get_keyword('OBJECT')), 'TEL_SIM') then gpi_update_wcs_basic,backbone,imsize=sz[1:2]
  
  backbone->set_keyword, 'COMMENT', "  For specification of Stokes WCS axis, see ",ext_num=1
  backbone->set_keyword, 'COMMENT', "  Greisen & Calabretta 2002 A&A 395, 1061, section 5.4",ext_num=1
  
  backbone->set_keyword, "NAXIS",    sz[0], /saveComment
  backbone->set_keyword, "NAXIS1",   sz[1], /saveComment, after='NAXIS'
  backbone->set_keyword, "NAXIS2",   sz[2], /saveComment, after='NAXIS1'
  backbone->set_keyword, "NAXIS3",   sz[3], /saveComment, after='NAXIS2'
  
  backbone->set_keyword, "FILETYPE", "Stokes Cube", "What kind of IFS file is this?"
  backbone->set_keyword, "WCSAXES",  3, "Number of axes in WCS system"
  backbone->set_keyword, "CTYPE3",   "STOKES",     "Polarization"
  backbone->set_keyword, "CUNIT3",   "N/A",       "Polarizations"
  backbone->set_keyword, "CRVAL3",   -6, " Stokes axis: image 0 is Y parallel, 1 is X parallel "
  
  backbone->set_keyword, "CRPIX3", 1.,         "Reference pixel location" ;;ds - was 0, but should be 1, right?
  backbone->set_keyword, "CD3_3",  1, "Stokes axis: images 0 and 1 give orthogonal polarizations." ;

  ;; Save output data.
  suffix='-podc'
  *dataset.currframe=polcube
  *dataset.currdq=dqcube
 
  ptr_free, dataset.currUncert  ; right now we're not creating an uncert cube
  
  
  @__end_primitive
end

