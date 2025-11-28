;; The first three lines of this file were inserted by DrRacket. They record metadata
;; about the language level of this file in a form that our tools can easily process.
#reader(lib "htdp-intermediate-lambda-reader.ss" "lang")((modname prova4) (read-case-sensitive #t) (teachpacks ()) (htdp-settings #(#t constructor repeating-decimal #f #t none #f () #f)))
; Solar System Simulator - Full Interactive Version
; Features: Images, Zoom, Orbit Lines, Mouse Hover Effect

(require 2htdp/image)
(require 2htdp/universe)

;; --- IMAGE LOADING SECTION ---
;; Assumes images are in a subfolder named "img"

(define EARTH-RAW-IMAGE (bitmap/file "./img/earth.png"))
(define EARTH-FINAL-IMAGE (scale 0.03 EARTH-RAW-IMAGE)) 

(define SUN-RAW-IMAGE (bitmap/file "./img/sun.png"))
(define SUN-FINAL-IMAGE (scale 0.2 SUN-RAW-IMAGE))    

(define MERCURY-RAW-IMAGE (bitmap/file "./img/mercury.png"))
(define MERCURY-FINAL-IMAGE (scale 0.02 MERCURY-RAW-IMAGE)) 

(define VENUS-RAW-IMAGE (bitmap/file "./img/venus.png"))
(define VENUS-FINAL-IMAGE (scale 0.02 VENUS-RAW-IMAGE))

(define MARS-RAW-IMAGE (bitmap/file "./img/mars.png"))
(define MARS-FINAL-IMAGE (scale 0.02 MARS-RAW-IMAGE))

(define JUPITER-RAW-IMAGE (bitmap/file "./img/jupiter.png"))
(define JUPITER-FINAL-IMAGE (scale 0.08 JUPITER-RAW-IMAGE))

(define SATURN-RAW-IMAGE (bitmap/file "./img/saturn.png"))
(define SATURN-FINAL-IMAGE (scale 0.08 SATURN-RAW-IMAGE))

(define URANUS-RAW-IMAGE (bitmap/file "./img/uranus.png"))
(define URANUS-FINAL-IMAGE (scale 0.015 URANUS-RAW-IMAGE)) 

(define NEPTUNE-RAW-IMAGE (bitmap/file "./img/neptune.png"))
(define NEPTUNE-FINAL-IMAGE (scale 0.015 NEPTUNE-RAW-IMAGE)) 


;; --- DATA DEFINITIONS ---

(define-struct location (x y))

(define-struct celestial-body (name radius orbit-au color angle angular-speed))
; interpretation:
; - name : name of the celestial body 
; - radius : radius in pixels (ignored if image used)
; - orbit-au : distance from the sun
; - color : color (ignored if image used)
; - angle : current position in radians
; - angular-speed : speed of rotation

(define-struct sim-state [bodies zoom mouse-x mouse-y])
; interpretation:
; - bodies : List<CelestialBody>
; - zoom   : Number
; - mouse-x : Mouse X position on screen
; - mouse-y : Mouse Y position on screen


;; --- CONSTANTS ---

(define SPEED-SCALE 0.01)  
(define ORBIT-STEP 80)

(define SUN  (make-celestial-body "Sun" 45 0 "yellow" 0 0)) 
(define MERCURY (make-celestial-body "Mercury" 4 (* 1 ORBIT-STEP) "gray" 0 (* 4.17 SPEED-SCALE)))
(define VENUS  (make-celestial-body "Venus" 8 (* 2 ORBIT-STEP) "orange" 1 (* 1.61 SPEED-SCALE)))
(define EARTH  (make-celestial-body "Earth" 9 (* 3 ORBIT-STEP) "blue" 2 (* 1.00 SPEED-SCALE)))
(define MARS   (make-celestial-body "Mars" 6 (* 4 ORBIT-STEP) "red" 3 (* 0.53 SPEED-SCALE)))
(define JUPITER (make-celestial-body "Jupiter" 16 (* 5 ORBIT-STEP) "sienna" 4 (* 0.084 SPEED-SCALE)))
(define SATURN (make-celestial-body "Saturn" 14 (* 6 ORBIT-STEP) "gold" 5 (* 0.034 SPEED-SCALE)))
(define URANUS (make-celestial-body "Uranus" 12 (* 7 ORBIT-STEP) "lightblue" 6 (* 0.012 SPEED-SCALE)))
(define NEPTUNE (make-celestial-body "Neptune" 11 (* 8 ORBIT-STEP) "navy" 0.5 (* 0.006 SPEED-SCALE)))

(define SCENE-WIDTH 1496)  
(define SCENE-HEIGHT 840) 
(define CENTER-X (/ SCENE-WIDTH 2))
(define CENTER-Y (/ SCENE-HEIGHT 2))
(define EMPTY-SCENE (empty-scene SCENE-WIDTH SCENE-HEIGHT "black"))

(define INITIAL-SOLAR-SYSTEM
  (list SUN MERCURY VENUS EARTH MARS JUPITER SATURN URANUS NEPTUNE))

; Initial state: bodies, zoom 1, mouse at 0,0
(define INITIAL-STATE (make-sim-state INITIAL-SOLAR-SYSTEM 1 0 0)) 


;; --- FUNCTIONS ---

(define (next-body-state body)
  (make-celestial-body 
   (celestial-body-name body) (celestial-body-radius body)
   (celestial-body-orbit-au body) (celestial-body-color body)
   (+ (celestial-body-angle body) (celestial-body-angular-speed body))
   (celestial-body-angular-speed body)))

(define (angle-to-location body)
  (local [
          (define orbit-pixels (celestial-body-orbit-au body))
          (define current-angle (celestial-body-angle body))]
    (make-location (* orbit-pixels (cos current-angle))
                   (* orbit-pixels (sin current-angle)))))

; Updates the physics (orbits) while keeping mouse coordinates same
(define (next-world current-state)
  (local [
          (define (update-bodies bodies)
            (cond 
              [(empty? bodies) '()]                            
              [else (cons (next-body-state (first bodies))     
                          (update-bodies (rest bodies)))]))]   
    (make-sim-state                                            
     (update-bodies (sim-state-bodies current-state))
     (sim-state-zoom current-state)
     (sim-state-mouse-x current-state)
     (sim-state-mouse-y current-state))))

; Updates the zoom level
(define (handle-key current-state key)
  (local [(define current-zoom (sim-state-zoom current-state))
          (define bodies (sim-state-bodies current-state))
          (define mx (sim-state-mouse-x current-state))
          (define my (sim-state-mouse-y current-state))]
    (cond
      [(or (key=? key "up") (key=? key "="))               
       (make-sim-state bodies (+ current-zoom 0.1) mx my)] 
      [(or (key=? key "down") (key=? key "-"))             
       (make-sim-state bodies (max 0.1 (- current-zoom 0.1)) mx my)]
      [else current-state])))

; Updates the mouse coordinates
(define (handle-mouse current-state x y event)
  (make-sim-state 
   (sim-state-bodies current-state)
   (sim-state-zoom current-state)
   x 
   y))

(define (draw-world current-state)
  (local [
          (define bodies (sim-state-bodies current-state))
          (define zoom (sim-state-zoom current-state))
          (define mx (sim-state-mouse-x current-state))
          (define my (sim-state-mouse-y current-state))

          (define (draw-body body scene)                    
            (local [(define loc (angle-to-location body))
                    (define radius-orbit (celestial-body-orbit-au body))
                    (define zoomed-orbit-radius (* radius-orbit zoom))
                    
                    ;; --- 1. DRAW ORBIT ---
                    (define orbit-img (circle (max 1 zoomed-orbit-radius) "outline" (color 255 255 255 50)))
                    (define scene-with-orbit
                      (if (> radius-orbit 0)
                          (place-image orbit-img CENTER-X CENTER-Y scene)
                          scene))

                    ;; --- 2. SELECT PLANET IMAGE ---
                    (define planet-base-image
                      (cond
                        [(string=? (celestial-body-name body) "Sun")     SUN-FINAL-IMAGE]   
                        [(string=? (celestial-body-name body) "Earth")   EARTH-FINAL-IMAGE] 
                        [(string=? (celestial-body-name body) "Mercury") MERCURY-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Venus")   VENUS-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Mars")    MARS-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Jupiter") JUPITER-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Saturn")  SATURN-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Uranus")  URANUS-FINAL-IMAGE]
                        [(string=? (celestial-body-name body) "Neptune") NEPTUNE-FINAL-IMAGE]
                        [else (circle (celestial-body-radius body) "solid" (celestial-body-color body))]))

                    (define final-planet-image (scale zoom planet-base-image))
                    
                    ;; --- 3. CALCULATE POSITIONS ---
                    (define x (+ CENTER-X (* (location-x loc) zoom)))
                    (define y (+ CENTER-Y (* (location-y loc) zoom)))
                    
                    ;; --- 4. HOVER LOGIC ---
                    ;; Calculate distance between mouse and planet center
                    (define distance (sqrt (+ (sqr (- mx x)) (sqr (- my y)))))
                    ;; Get planet radius (half the width of the image)
                    (define planet-radius (/ (image-width final-planet-image) 2))
                    
                    ;; Check if mouse is hovering
                    (define is-hovering (< distance planet-radius))
                    
                    ;; Create glow effect
                    (define highlight-img 
                      (circle (+ planet-radius 5) "outline" "white")) 
                    
                    (define scene-with-highlight
                      (if is-hovering
                          (place-image highlight-img x y scene-with-orbit)
                          scene-with-orbit))] 
              
              ;; Draw Planet
              (place-image final-planet-image x y scene-with-highlight)))

    (define (draw-all-bodies bodies-remaining current-scene)
      (cond
        [(empty? bodies-remaining) current-scene]             
        [else 
         (draw-all-bodies (rest bodies-remaining)             
          (draw-body (first bodies-remaining) current-scene))]))
    ]
    
    (draw-all-bodies bodies EMPTY-SCENE)))

(define (main initial-state)
  (big-bang initial-state
    (on-tick next-world 1/100)
    (to-draw draw-world)
    (on-key handle-key)
    (on-mouse handle-mouse)))

(main INITIAL-STATE)