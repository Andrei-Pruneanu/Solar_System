;; The first three lines of this file were inserted by DrRacket. They record metadata
;; about the language level of this file in a form that our tools can easily process.
#reader(lib "htdp-intermediate-lambda-reader.ss" "lang")((modname Solar1) (read-case-sensitive #t) (teachpacks ()) (htdp-settings #(#t constructor repeating-decimal #f #t none #f () #f)))
; Solar System Simulator

(require 2htdp/image)
(require 2htdp/universe)

;; --- IMAGE LOADING SECTION ---

;; 1. Load Earth
(define EARTH-RAW-IMAGE (bitmap/file "./img/earth.png"))
(define EARTH-FINAL-IMAGE (scale 0.03 EARTH-RAW-IMAGE)) ; Adjust 0.05 to resize Earth

;; 2. Load Sun
(define SUN-RAW-IMAGE (bitmap/file "./img/sun.png"))
(define SUN-FINAL-IMAGE (scale 0.2 SUN-RAW-IMAGE))    ; Adjust 0.1 to resize Sun

;; 3. Load Mercury
(define MERCURY-RAW-IMAGE (bitmap/file "./img/mercury.png"))
(define MERCURY-FINAL-IMAGE (scale 0.02 MERCURY-RAW-IMAGE)) 

;; 4. Load Venus
(define VENUS-RAW-IMAGE (bitmap/file "./img/venus.png"))
(define VENUS-FINAL-IMAGE (scale 0.02 VENUS-RAW-IMAGE))

;; 5. Load Mars
(define MARS-RAW-IMAGE (bitmap/file "./img/mars.png"))
(define MARS-FINAL-IMAGE (scale 0.02 MARS-RAW-IMAGE))

;; 6. Load Jupiter
(define JUPITER-RAW-IMAGE (bitmap/file "./img/jupiter.png"))
(define JUPITER-FINAL-IMAGE (scale 0.08 JUPITER-RAW-IMAGE))

;; 7. Load Saturn
(define SATURN-RAW-IMAGE (bitmap/file "./img/saturn.png"))
(define SATURN-FINAL-IMAGE (scale 0.08 SATURN-RAW-IMAGE))

;; 8. Load Uranus
(define URANUS-RAW-IMAGE (bitmap/file "./img/uranus.png"))
(define URANUS-FINAL-IMAGE (scale 0.015 URANUS-RAW-IMAGE)) 

;; 9. Load Neptune
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

; A SimState is a structure: (define-struct sim-state [bodies zoom])
;                            make-sim-state : List<CelestialBody> Number
; interpretation:
; - bodies : List<CelestialBody>
; - zoom   : Number (for example 1.0 is normal, 2.0 is 2x zoom)
(define-struct sim-state [bodies zoom])

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

; size of overall scene
(define SCENE-WIDTH 1496)  
(define SCENE-HEIGHT 840) 
(define CENTER-X (/ SCENE-WIDTH 2))
(define CENTER-Y (/ SCENE-HEIGHT 2))
(define EMPTY-SCENE (empty-scene SCENE-WIDTH SCENE-HEIGHT "black"))

; list of planets
(define INITIAL-SOLAR-SYSTEM
  (list SUN MERCURY VENUS EARTH MARS JUPITER SATURN URANUS NEPTUNE))

; initial state including zoom
(define INITIAL-STATE (make-sim-state INITIAL-SOLAR-SYSTEM 1)) 

;; Functions:
; -----------------

; next-body-state : CelestialBody -> CelestialBody
; given a celestial body, produce a body just like it but with its angle increased by its angular speed
; header: (define (next-body-state body) CelestialBody)
; template:

(define (next-body-state body)
  (make-celestial-body 
   (celestial-body-name body) (celestial-body-radius body)
   (celestial-body-orbit-au body) (celestial-body-color body)
   (+ (celestial-body-angle body) (celestial-body-angular-speed body)) ; increase the angle by how much the planet rotates during one tick
   (celestial-body-angular-speed body)))

; angle-to-location : CelestialBody -> Location
; compute the rectangular (x, y) position of a celestial body from its orbit radius and current angle
; header: (define (angle-to-location body) Location)
; template:

(define (angle-to-location body)
  (local [
          (define orbit-pixels (celestial-body-orbit-au body))
          (define current-angle (celestial-body-angle body))]
    (make-location (* orbit-pixels (cos current-angle))        ; Move the planet orbit-pixels away from the center, pointing in the direction given by the planet’s angle
                  (* orbit-pixels (sin current-angle)))))

; next-world : SimState -> SimState
; advance every celestial body in the world by one tick
; header: (define (next-world world-list) World)
; template:

(define (next-world current-state)
  (local [
          (define (update-bodies bodies)
            (cond 
              [(empty? bodies) '()]                           ; Base case: empty list returns empty list
              [else (cons (next-body-state (first bodies))    ; Apply transformation to the head
                          (update-bodies (rest bodies)))]))]  ; Recursive case
    (make-sim-state                                           ; Create new state with updated bodies, but keep existing zoom
     (update-bodies (sim-state-bodies current-state))
     (sim-state-zoom current-state))))

; handle-key : SimState String -> SimState
; changes the zoom level when Up or Down arrows are pressed
; header: (define (handle-key current-state key) SimState)
; template:

(define (handle-key current-state key)
  (local [(define current-zoom (sim-state-zoom current-state))
          (define bodies (sim-state-bodies current-state))]
    (cond
      [(or (key=? key "up") (key=? key "="))                   ; Zoom IN
       (make-sim-state bodies (+ current-zoom 0.1))]
      [(or (key=? key "down") (key=? key "-"))                 ; Zoom OUT
       (make-sim-state bodies (max 0.1 (- current-zoom 0.1)))] ; (max 0.1 ...) -> prevents zooming out until the solar system disappears
      [else current-state])))

; draw-world : SimState -> Image
; draw all celestial bodies of the world on a black background with the sun at the center of the scene
; header: (define (draw-world world-list) Image)
; template:

(define (draw-world current-state)
  (local [
          (define bodies (sim-state-bodies current-state))
          (define zoom (sim-state-zoom current-state))                      ; get the current zoom 

          (define (draw-body body scene)                                    ; draws one single planet onto a given scene
            (local [(define loc (angle-to-location body))                   ; loc is the planet’s position in x-y coordinates
                    (define radius-orbit (celestial-body-orbit-au body))
                    (define zoomed-orbit-radius (* radius-orbit zoom))
                    (define orbit-img (circle (max 1 zoomed-orbit-radius) "outline" (color 255 255 255 50)))

                    (define scene-with-orbit
                      (if (> radius-orbit 0)
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
                    ; Scale coordinates by zoom
                    (define x (+ CENTER-X (* (location-x loc) zoom)))
                    (define y (+ CENTER-Y (* (location-y loc) zoom)))]

              (place-image final-planet-image
               x y
               scene-with-orbit)))

    ; draw-all-bodies: List<CelestialBody> Image -> Image
    ; draw each body onto the scene and return the final image
    ; header: (define (draw-all-bodies bodies-remaining current-scene) Image)
    ; template:
    
    (define (draw-all-bodies bodies-remaining current-scene)
      (cond
        [(empty? bodies-remaining) current-scene]              ; Base case: if the list is empty, return the accumulated scene
        [else 
         (draw-all-bodies (rest bodies-remaining)              ; Recursive case
          (draw-body (first bodies-remaining) current-scene))] ; draw the current body onto the scene
        ))
    ]
    
    (draw-all-bodies bodies EMPTY-SCENE)))   ; start with the full list and an empty scene

; main : SimState -> SimState
; run the solar-system animation starting from the given world

(define (main initial-state)
  (big-bang initial-state
    (on-tick next-world 1/100)
    (to-draw draw-world)
    (on-key handle-key)))

(main INITIAL-STATE)