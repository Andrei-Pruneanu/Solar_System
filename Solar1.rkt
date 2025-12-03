;; The first three lines of this file were inserted by DrRacket. They record metadata
;; about the language level of this file in a form that our tools can easily process.
#reader(lib "htdp-intermediate-lambda-reader.ss" "lang")((modname Solar1) (read-case-sensitive #t) (teachpacks ()) (htdp-settings #(#t constructor repeating-decimal #f #t none #f () #f)))
; Solar System Simulator 

(require 2htdp/image)
(require 2htdp/universe)

;; --- IMAGE LOADING SECTION ---

; 1. Load Earth
(define EARTH-RAW-IMAGE (bitmap/file "./img/earth.png"))
(define EARTH-FINAL-IMAGE (scale 0.03 EARTH-RAW-IMAGE)) 

; 2. Load Sun
(define SUN-RAW-IMAGE (bitmap/file "./img/sun.png"))
(define SUN-FINAL-IMAGE (scale 0.2 SUN-RAW-IMAGE))    

; 3. Load Mercury
(define MERCURY-RAW-IMAGE (bitmap/file "./img/mercury.png"))
(define MERCURY-FINAL-IMAGE (scale 0.02 MERCURY-RAW-IMAGE)) 

; 4. Load Venus
(define VENUS-RAW-IMAGE (bitmap/file "./img/venus.png"))
(define VENUS-FINAL-IMAGE (scale 0.02 VENUS-RAW-IMAGE))

; 5. Load Mars
(define MARS-RAW-IMAGE (bitmap/file "./img/mars.png"))
(define MARS-FINAL-IMAGE (scale 0.02 MARS-RAW-IMAGE))

; 6. Load Jupiter
(define JUPITER-RAW-IMAGE (bitmap/file "./img/jupiter.png"))
(define JUPITER-FINAL-IMAGE (scale 0.043 JUPITER-RAW-IMAGE))

; 7. Load Saturn
(define SATURN-RAW-IMAGE (bitmap/file "./img/saturn.png"))
(define SATURN-FINAL-IMAGE (scale 0.08 SATURN-RAW-IMAGE))

; 8. Load Uranus
(define URANUS-RAW-IMAGE (bitmap/file "./img/uranus.png"))
(define URANUS-FINAL-IMAGE (scale 0.015 URANUS-RAW-IMAGE)) 

; 9. Load Neptune
(define NEPTUNE-RAW-IMAGE (bitmap/file "./img/neptune.png"))
(define NEPTUNE-FINAL-IMAGE (scale 0.015 NEPTUNE-RAW-IMAGE))


;; Data Definitions:
; -----------------

; A Location is a structure: (define-struct location [x y])
;                            make-location : Number Number -> Location
; interpretation: (x y) is a position in pixels relative to the center of the scene (right is +x, up is +y)
(define-struct location (x y))

; A CelestialBody is a structure: (define-struct celestial-body [name radius orbit-au color angle angular-speed])
;                                 make-celestial-body : String Number Number String Number Number -> CelestialBody
; interpretation:
; - name          : name of the celestial body 
; - radius        : radius of the body in pixels
; - orbit-au      : distance from the sun in pixels (orbit radius)
; - color         : color used when drawing the body
; - angle         : current polar angle (radians) on its circular orbit
; - angular-speed : change in angle (radians) per clock tick
(define-struct celestial-body (name radius orbit-au color angle angular-speed))

; A SimState is a structure: (define-struct sim-state [bodies zoom mouse-x mouse-y locked-body-name speed-index])
;                            make-sim-state : List<CelestialBody> Number Number Number String Number -> SimState
; interpretation:
; - bodies           : List of celestial bodies
; - zoom             : Number (e.g. 1.0 is normal, 2.0 is 2x zoom)
; - mouse-x, mouse-y : Coordinates of the mouse (for hover effect)
; - locked-body-name : The name of the planet the camera is following (or "Sun")
; - speed-index      : The current index in the speed-levels list (0, 1, 2...)
(define-struct sim-state [bodies zoom mouse-x mouse-y locked-body-name speed-index])

;; Constants:
; -----------------

(define SPEED-SCALE 0.01)  
(define ORBIT-STEP 80)    ; the distance (in pixels) between the orbits of the planets

(define SUN  (make-celestial-body "Sun" 45 0 "yellow" 0 0)) 
(define MERCURY (make-celestial-body "Mercury" 4 (* 1 ORBIT-STEP) "gray" 0 (* 4.17 SPEED-SCALE)))
(define VENUS  (make-celestial-body "Venus" 8 (* 2 ORBIT-STEP) "orange" 1 (* 1.61 SPEED-SCALE)))
(define EARTH  (make-celestial-body "Earth" 9 (* 3 ORBIT-STEP) "blue" 2 (* 1.00 SPEED-SCALE)))
(define MARS   (make-celestial-body "Mars" 6 (* 4 ORBIT-STEP) "red" 3 (* 0.53 SPEED-SCALE)))
(define JUPITER (make-celestial-body "Jupiter" 16 (* 5 ORBIT-STEP) "sienna" 4 (* 0.084 SPEED-SCALE)))
(define SATURN (make-celestial-body "Saturn" 14 (* 6 ORBIT-STEP) "gold" 5 (* 0.034 SPEED-SCALE)))
(define URANUS (make-celestial-body "Uranus" 12 (* 7 ORBIT-STEP) "lightblue" 6 (* 0.012 SPEED-SCALE)))
(define NEPTUNE (make-celestial-body "Neptune" 11 (* 8 ORBIT-STEP) "navy" 0.5 (* 0.006 SPEED-SCALE)))

;; Predefined Speed Levels: (List "Label Name" Multiplier-Value)
(define SPEED-LEVELS
  (list
   (list "Paused"       0.0)
   (list "30 Min/Sec"   0.0015)
   (list "5 Hours/Sec"  0.015)
   (list "1 Day/Sec"    0.07)
   (list "15 Days/Sec"  1.0)     ; Original Normal Speed
   (list "1 Month/Sec"  2.0)
   (list "6 Months/Sec" 12.0)
   (list "1 Year/Sec"   24.0)))

; size of overall scene
(define SCENE-WIDTH 1496)  
(define SCENE-HEIGHT 840) 
(define CENTER-X (/ SCENE-WIDTH 2))
(define CENTER-Y (/ SCENE-HEIGHT 2))
(define EMPTY-SCENE (empty-scene SCENE-WIDTH SCENE-HEIGHT "black"))

; list of planets
(define INITIAL-SOLAR-SYSTEM
  (list SUN MERCURY VENUS EARTH MARS JUPITER SATURN URANUS NEPTUNE))

; initial state: zoom=1, mouse at (0,0), locked on "Sun", speed-index=4 (which is "15 Days/Sec")
(define INITIAL-STATE (make-sim-state INITIAL-SOLAR-SYSTEM 1 0 0 "Sun" 4)) 

;; Functions:
; -----------------

; next-body-state : CelestialBody Number -> CelestialBody
; given a celestial body and speed multiplier, produce a body just like it but with its angle increased
; header: (define (next-body-state body speed-mult) CelestialBody)
; template:

(define (next-body-state body speed-mult)
  (make-celestial-body 
   (celestial-body-name body) (celestial-body-radius body)
   (celestial-body-orbit-au body) (celestial-body-color body)
   ; Increase angle based on angular-speed AND the speed multiplier
   (+ (celestial-body-angle body) (* (celestial-body-angular-speed body) speed-mult)) 
   (celestial-body-angular-speed body)))

; angle-to-location : CelestialBody -> Location
; compute the rectangular (x, y) position of a celestial body from its orbit radius and current angle
; header: (define (angle-to-location body) Location)
; template:

(define (angle-to-location body)
  (local [
          (define orbit-pixels (celestial-body-orbit-au body))
          (define current-angle (celestial-body-angle body))]
    (make-location (* orbit-pixels (cos current-angle))        ; Move the planet orbit-pixels away from the center
                   (* orbit-pixels (sin current-angle)))))

; find-body-by-name : List<CelestialBody> String -> CelestialBody
; Helper function to find a body in the list to lock the camera on (defaults to Sun if not found)
; header: (define (find-body-by-name bodies name) CelestialBody)
; template:

(define (find-body-by-name bodies name)
  (cond
    [(empty? bodies) SUN] 
    [(string=? (celestial-body-name (first bodies)) name) (first bodies)]
    [else (find-body-by-name (rest bodies) name)]))

; next-world : SimState -> SimState
; advance every celestial body in the world by one tick and preserve camera/zoom state
; header: (define (next-world current-state) SimState)
; template:

(define (next-world current-state)
  (local [
          (define current-idx (sim-state-speed-index current-state))
          ; Get the multiplier value (second element) from the current speed pair
          (define speed-mult (second (list-ref SPEED-LEVELS current-idx)))

          (define (update-bodies bodies)
            (cond 
              [(empty? bodies) '()]                                      ; Base case: empty list returns empty list
              [else (cons (next-body-state (first bodies) speed-mult)    ; Apply transformation to the head with speed
                          (update-bodies (rest bodies)))]))]             ; Recursive case
    (make-sim-state 
     (update-bodies (sim-state-bodies current-state))
     (sim-state-zoom current-state)
     (sim-state-mouse-x current-state)
     (sim-state-mouse-y current-state)
     (sim-state-locked-body-name current-state)
     (sim-state-speed-index current-state))))

; handle-key : SimState String -> SimState
; changes the zoom level or speed index when Up/Down arrows or +/- keys are pressed
; header: (define (handle-key current-state key) SimState)
; template:

(define (handle-key current-state key)
  (local [(define current-zoom (sim-state-zoom current-state))
          (define bodies (sim-state-bodies current-state))
          (define mx (sim-state-mouse-x current-state))
          (define my (sim-state-mouse-y current-state))
          (define locked (sim-state-locked-body-name current-state))
          (define idx (sim-state-speed-index current-state))
          (define max-idx (- (length SPEED-LEVELS) 1))]
    (cond
      ; Zoom Controls:
      [(or (key=? key "up") (key=? key "="))                   ; Zoom IN
       (make-sim-state bodies (+ current-zoom 0.1) mx my locked idx)]
      [(or (key=? key "down") (key=? key "-"))                 ; Zoom OUT
       (make-sim-state bodies (max 0.1 (- current-zoom 0.1)) mx my locked idx)] 
      
      ; Speed Controls - Cycle through predefined levels
      [(key=? key "i")                                         ; Increase Speed Index
       (make-sim-state bodies current-zoom mx my locked (min max-idx (+ idx 1)))]
      [(key=? key "d")                                         ; Decrease Speed Index
       (make-sim-state bodies current-zoom mx my locked (max 0 (- idx 1)))]
      
      [else current-state])))

; handle-mouse : SimState Number Number MouseEvent -> SimState
; Updates mouse coordinates and handles clicks for locking camera on planets
; header: (define (handle-mouse current-state x y event) SimState)
; template:

(define (handle-mouse current-state x y event)
  (local [
          (define bodies (sim-state-bodies current-state))
          (define zoom (sim-state-zoom current-state))
          (define locked-name (sim-state-locked-body-name current-state))
          (define idx (sim-state-speed-index current-state))
          
          ; Logic to find which planet was clicked
          (define (get-clicked-planet-name bodies)
            (cond
              [(empty? bodies) locked-name] 
              [else
               (local [
                       (define body (first bodies))
                       ; Calculate where this planet is currently drawn on screen
                       (define target-body (find-body-by-name (sim-state-bodies current-state) locked-name))
                       (define target-loc (angle-to-location target-body))
                       (define body-loc (angle-to-location body))
                       
                       (define relative-x (- (location-x body-loc) (location-x target-loc)))
                       (define relative-y (- (location-y body-loc) (location-y target-loc)))
                       
                       (define draw-x (+ CENTER-X (* relative-x zoom)))
                       (define draw-y (+ CENTER-Y (* relative-y zoom)))
                       
                       (define distance (sqrt (+ (sqr (- x draw-x)) (sqr (- y draw-y)))))
                       (define hit-radius 30)] 
                 (if (< distance hit-radius)
                     (celestial-body-name body) 
                     (get-clicked-planet-name (rest bodies))))]))]
    
    (cond
      [(mouse=? event "button-down")
       (make-sim-state bodies zoom x y (get-clicked-planet-name bodies) idx)]
      [else 
       (make-sim-state bodies zoom x y locked-name idx)])))

; draw-world : SimState -> Image
; draw all celestial bodies of the world with zoom and camera tracking
; header: (define (draw-world current-state) Image)
; template:

(define (draw-world current-state)
  (local [
          (define bodies (sim-state-bodies current-state))
          (define zoom (sim-state-zoom current-state))
          (define mx (sim-state-mouse-x current-state))
          (define my (sim-state-mouse-y current-state))
          (define locked-name (sim-state-locked-body-name current-state))
          (define idx (sim-state-speed-index current-state))
          
          ; Retrieve the Speed Label (first element) from the list using the current index
          (define speed-label (first (list-ref SPEED-LEVELS idx)))
          
          ; Camera logic: Find the target body and its location
          (define target-body (find-body-by-name bodies locked-name))
          (define target-loc (angle-to-location target-body))

          (define (draw-body body scene) 
            (local [(define loc (angle-to-location body)) 
                    (define radius-orbit (celestial-body-orbit-au body))
                    (define zoomed-orbit-radius (* radius-orbit zoom))
                    
                    ; Camera shift calculation: (PlanetPos - TargetPos)
                    ; If a planet is the target, its relative pos is 0, so it draws at center.
                    (define relative-x (- (location-x loc) (location-x target-loc)))
                    (define relative-y (- (location-y loc) (location-y target-loc)))
                    
                    ; Orbit drawing (Only if locked on Sun to prevent visual clutter)
                    (define orbit-img (circle (max 1 zoomed-orbit-radius) "outline" (color 255 255 255 50)))
                    (define scene-with-orbit
                      (if (and (> radius-orbit 0) (string=? locked-name "Sun"))
                          (place-image orbit-img CENTER-X CENTER-Y scene)
                          scene))

                    (define planet-base-image
                      (cond
                        [(string=? (celestial-body-name body) "Sun")    SUN-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Earth")  EARTH-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Mercury") MERCURY-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Venus")  VENUS-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Mars")   MARS-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Jupiter") JUPITER-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Saturn") SATURN-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Uranus") URANUS-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Neptune") NEPTUNE-FINAL-IMAGE]
                        [else (circle (celestial-body-radius body) "solid" (celestial-body-color body))]))

                    (define final-planet-image (scale zoom planet-base-image))
                    
                    ; Scale coordinates by zoom and center them
                    (define x (+ CENTER-X (* relative-x zoom)))
                    (define y (+ CENTER-Y (* relative-y zoom)))
                    
                    ; Hover effect
                    (define distance (sqrt (+ (sqr (- mx x)) (sqr (- my y)))))
                    (define planet-radius (/ (image-width final-planet-image) 2))
                    (define is-hovering (< distance planet-radius))
                    (define highlight-img (circle (+ planet-radius 5) "outline" "white"))
                    
                    (define scene-with-highlight
                       (if is-hovering
                           (place-image highlight-img x y scene-with-orbit)
                           scene-with-orbit))]

              (place-image final-planet-image
               x y
               scene-with-highlight)))

          ; draw-all-bodies: List<CelestialBody> Image -> Image
          ; draw each body onto the scene and return the final image
          ; header: (define (draw-all-bodies bodies-remaining current-scene) Image)
          ; template:

          (define (draw-all-bodies bodies-remaining current-scene)
            (cond
              [(empty? bodies-remaining) current-scene]                ; Base case
              [else 
               (draw-all-bodies (rest bodies-remaining)                ; Recursive case
               (draw-body (first bodies-remaining) current-scene))]))
          
          ; Heads-Up Display (Top Left: Camera + Speed)
          (define HUD-IMAGE 
            (above/align "left"
              (text (string-append "Camera Locked: " locked-name) 16 "white")
              (text "" 2 "black")
              (text (string-append "Speed: " speed-label) 16 "white")))

          ; Legend (Bottom Left)
          (define LEGEND-IMAGE
            (above/align "left"
              (text "LEGEND" 16 "yellow")
              (text "" 2 "black")
              (text "Arrows: Zoom In/Out" 14 "white")
              (text "" 2 "black")
              (text "I / D: Speed Up/Down" 14 "white") 
              (text "" 2 "black")  
              (text "Click Planet: Lock Camera" 14 "white"))) 
          ]
    
    ; Draw everything on the scene
    (place-image HUD-IMAGE 
                 120 50  ; Heads-Up Display Position (x, y) - Top Left
                 (place-image LEGEND-IMAGE
                              120 (- SCENE-HEIGHT 60) ; Legend Position - Bottom Left 
                              (draw-all-bodies bodies EMPTY-SCENE)))))

; main : SimState -> SimState
; run the solar-system animation starting from the given world 
(define (main initial-state)
  (big-bang initial-state
    (on-tick next-world 1/100)
    (to-draw draw-world)
    (on-key handle-key)
    (on-mouse handle-mouse)))

(main INITIAL-STATE)