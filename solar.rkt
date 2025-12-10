;; The first three lines of this file were inserted by DrRacket. They record metadata
;; about the language level of this file in a form that our tools can easily process.
#reader(lib "htdp-intermediate-lambda-reader.ss" "lang")((modname solar) (read-case-sensitive #t) (teachpacks ()) (htdp-settings #(#t constructor repeating-decimal #f #t none #f () #f)))
; Solar System Simulator

(require 2htdp/image)
(require 2htdp/universe)

; -----------------------------
; 1. IMAGE LOADING & CONSTANTS
; -----------------------------

; --- MAIN PLANET IMAGES ---
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
(define SATURN-FINAL-IMAGE (scale 0.12 SATURN-RAW-IMAGE))
; 8. Load Uranus
(define URANUS-RAW-IMAGE (bitmap/file "./img/uranus.png"))
(define URANUS-FINAL-IMAGE (scale 0.04 URANUS-RAW-IMAGE))
; 9. Load Neptune
(define NEPTUNE-RAW-IMAGE (bitmap/file "./img/neptune.png"))
(define NEPTUNE-FINAL-IMAGE (scale 0.035 NEPTUNE-RAW-IMAGE))

; --- GALLERY IMAGES ---
; We define a helper to load 3 images for a planet at once
(define (load-gallery name)
  (list (bitmap/file (string-append "./img/" name "-close-up-1.png"))
        (bitmap/file (string-append "./img/" name "-close-up-2.png"))
        (bitmap/file (string-append "./img/" name "-close-up-3.png"))))

; Loading all galleries into memory at startup
(define GAL-SUN     (load-gallery "sun"))
(define GAL-MERCURY (load-gallery "mercury"))
(define GAL-VENUS   (load-gallery "venus"))
(define GAL-EARTH   (load-gallery "earth"))
(define GAL-MARS    (load-gallery "mars"))
(define GAL-JUPITER (load-gallery "jupiter"))
(define GAL-SATURN  (load-gallery "saturn"))
(define GAL-URANUS  (load-gallery "uranus"))
(define GAL-NEPTUNE (load-gallery "neptune"))

; Simulation Constants
(define SPEED-SCALE 0.01)  
(define ORBIT-STEP 110)    ; the distance (in pixels) between the orbits of the planets

; Size of overall scene
(define SCENE-WIDTH 1496)  
(define SCENE-HEIGHT 840) 
(define CENTER-X (/ SCENE-WIDTH 2))
(define CENTER-Y (/ SCENE-HEIGHT 2))

; UI Constants
(define PANEL-WIDTH 350) 
(define PANEL-HEIGHT 280)

; Constants for fixed gallery size
(define GALLERY-VIEW-WIDTH 240)
(define GALLERY-VIEW-HEIGHT 140)

(define PANEL-X (- SCENE-WIDTH PANEL-WIDTH 20)) 
(define PANEL-Y (- SCENE-HEIGHT PANEL-HEIGHT 20)) 
(define BUTTON-HEIGHT 30)
(define BUTTON-WIDTH (/ PANEL-WIDTH 3)) 

; Predefined Speed Levels:
(define SPEED-LEVELS
  (list (list "Paused" 0.0)
        (list "30 Min/Sec" 0.0015)
        (list "5 Hours/Sec" 0.015)
        (list "1 Day/Sec" 0.07)
        (list "15 Days/Sec" 1.0)   ; Original Normal Speed
        (list "1 Month/Sec" 2.0)
        (list "6 Months/Sec" 12.0)
        (list "1 Year/Sec" 24.0)))

; -----------------------------
; 2. DATA DEFINITIONS
; ----------------------------- 

; A Location is a structure: (define-struct location [x y])
;                            make-location : Number Number -> Location
; interpretation: (x y) is a position in pixels relative to the center of the scene (right is +x, up is +y)
(define-struct location [x y])

; A Satellite is a structure: (define-struct satellite [name radius dist color angle speed])
;                             make-satellite:  String Number Number String Number Number -> Satellite
; interpretation: 
; - name    : name of the moon
; - radius  : visual radius in pixels
; - dist    : distance from the parent planet
; - color   : visual color
; - angle   : current angle in radians
; - speed   : rotational speed
(define-struct satellite [name radius dist color angle speed])

; A Probe is a structure: (define-struct probe [x y vx vy fuel status departure-planet target-planet launch-time])
;                         make-probe : Number Number Number Number Number String String String Number -> Probe
; interpretation:
; - x, y             : current position in pixels (relative to center)
; - vx, vy           : velocity vector (pixels per tick)
; - fuel             : remaining fuel percentage (0-100)
; - status           : "planning" | "launching" | "in-transit" | "arrived" | "failed"
; - departure-planet : name of starting planet
; - target-planet    : name of destination planet
; - launch-time      : simulation time when launched (in ticks)
(define-struct probe [x y vx vy fuel status departure-planet target-planet launch-time])

; A Mission is a structure: (define-struct mission [departure target status probe])
;                           make-mission : String String String Probe -> Mission
; interpretation:
; - departure : name of departure planet
; - target    : name of target planet
; - status    : "planning" | "active" | "completed" | "failed"
; - probe     : the probe object (or #f if not launched yet)
(define-struct mission [departure target status probe])

; A CelestialBody is a structure: (define-struct celestial-body [name radius orbit-au color angle angular-speed satellites])
;                                 make-celestial-body : String Number Number String Number Number Number -> CelestialBody
; interpretation:
; - name          : name of the celestial body 
; - radius        : radius of the body in pixels
; - orbit-au      : distance from the sun in pixels (orbit radius)
; - color         : color used when drawing the body
; - angle         : current polar angle (radians) on its circular orbit
; - angular-speed : change in angle (radians) per clock tick
; - satellites    : list of moons orbiting this planet
(define-struct celestial-body [name radius orbit-au color angle angular-speed satellites])

; An Asteroid is a structure: (define-struct asteroid (angle dist speed size color))
;                             make-asteroid : Number Number Number Number String -> Asteroid
; interpretation:
; - angle   : current angle
; - dist    : distance from sun
; - speed   : orbital speed
; - size    : visual size
; - color   : visual color
(define-struct asteroid [angle dist speed size color])

; A Comet is a structure: (define-struct comet [x y vx vy size])
;                         make-comet : Number Number Number Number Number
; interpretation: represents a comet moving freely
; - x, y    : current position
; - vx, vy  : velocity vector
; - size    : visual size
(define-struct comet [x y vx vy size])

; A SimState is a structure: (define-struct sim-state [bodies zoom mouse-x mouse-y locked-body-name speed-index active-tab gallery-index asteroid-belt active-comets day-counter])
;                            make-sim-state : List<CelestialBody> Number Number Number String Number String Number List<Asteroid> List<Comet> -> SimState
; interpretation:
; - bodies             : list of planets
; - zoom               : current zoom level
; - mouse-x, mouse-y   : mouse coordinates
; - locked-body-name   : name of the planet the camera is following
; - speed-index        : index in SPEED-LEVELS list
; - active-tab         : current UI tab ("STATS", "INFO", or "PHOTOS")
; - gallery-index      : current photo index (1, 2, or 3) for the gallery
; - asteroid-belt      : list of active asteroids
; - active-comets      : list of active comets
; - active-missions    : list of Mission objects currently running or completed
; - mission-mode       : "none" | "selecting-departure" | "selecting-target"
; - selected-departure : name of the planet chosen as the start of a mission
; - sim-time           : absolute simulation ticks counter (used for physics calculations)
; - day-counter        : the total number of days passed since Jan 1st, 2025 (e.g., 345)
(define-struct sim-state [bodies zoom mouse-x mouse-y locked-body-name speed-index active-tab gallery-index asteroid-belt active-comets active-missions mission-mode selected-departure sim-time day-counter])

; -----------------------------
; 3. HELPER FUNCTIONS & LOGIC
; -----------------------------

;; Input/output
; make-moon : String Number Number String Number -> Satellite
; Helper function to create a moon with a random starting angle
; header: (define (make-moon name r dist col speed) Satellite)

(define (make-moon name r dist col speed)
  (make-satellite name r dist col (random 360) speed))

;; Input/output
; angle-to-location : CelestialBody -> Location
; Converts the polar coordinates (orbit-au, angle) of a body to Cartesian (x, y)
; header: (define (angle-to-location body) Location) 

(define (angle-to-location body)
  (make-location (* (celestial-body-orbit-au body) (cos (celestial-body-angle body)))
                 (* (celestial-body-orbit-au body) (sin (celestial-body-angle body)))))
; Tests
(check-expect (location-x (angle-to-location (make-celestial-body "Test" 10 100 "red" 0 0 '()))) 100)
(check-within (location-y (angle-to-location (make-celestial-body "Test" 10 100 "red" 0 0 '()))) 0 0.01)

;; Input/output
; find-body-by-name : List<CelestialBody> String -> CelestialBody
; Recursively searches for a planet by name. Returns a default Sun if not found
; header: (define (find-body-by-name bodies name) CelestialBody)
; template:
; (define (find-body-by-name bodies name)
;   (cond
;       [(empty? bodies) ...]
;       [(string=? (celestial-body-name (first bodies)) name) ...]
;       [else ...]))

(define (find-body-by-name bodies name)
  (cond [(empty? bodies) (make-celestial-body "Sun" 45 0 "yellow" 0 0 '())] 
        [(string=? (celestial-body-name (first bodies)) name) (first bodies)] 
        [else (find-body-by-name (rest bodies) name)]))

; Tests
(define SHORT-LIST (list (make-celestial-body "A" 1 1 "c" 0 0 '())
                         (make-celestial-body "B" 2 2 "d" 0 0 '())))
(check-expect (celestial-body-name (find-body-by-name SHORT-LIST "Z")) "Sun")
(check-expect (find-body-by-name SHORT-LIST "B") (make-celestial-body "B" 2 2 "d" 0 0 '()))

;; Input/output
; get-planet-info : String -> List<String>
; Returns a list of strings containing stats and description for a specific planet
; header: (define (get-planet-info name) List<String>)
; template:
; (define (get-planet-info name)
;   (cond
;     [(string=? name "Sun")     ...]
;     [(string=? name "Mercury") ...]
;     [(string=? name "Venus")   ...]
;     [(string=? name "Earth")   ...]
;     [(string=? name "Mars")    ...]
;     [(string=? name "Jupiter") ...]
;     [(string=? name "Saturn")  ...]
;     [(string=? name "Uranus")  ...]
;     [(string=? name "Neptune") ...]
;     [else (list "?" "?" "?" "No Data" "Available" ".")]))

(define (get-planet-info name)
  (cond
    [(string=? name "Sun")     (list "1.989 x 10^30 kg" "1.39 million km" "5,500 C" "The star at the center" "of our Solar System." "It provides light and energy.")]
    [(string=? name "Mercury") (list "3.285 x 10^23 kg" "4,879 km" "167 C" "The smallest planet." "It has no atmosphere" "to retain heat.")]
    [(string=? name "Venus")   (list "4.867 x 10^24 kg" "12,104 km" "464 C" "The hottest planet due" "to a thick toxic atmosphere" "trapping heat.")]
    [(string=? name "Earth")   (list "5.972 x 10^24 kg" "12,742 km" "15 C" "Our home planet." "The only known planet" "to support life.")]
    [(string=? name "Mars")    (list "6.39 x 10^23 kg"  "6,779 km" "-65 C" "The Red Planet." "Dusty, cold, with a" "very thin atmosphere.")]
    [(string=? name "Jupiter") (list "1.898 x 10^27 kg" "139,820 km" "-110 C" "Gas giant. The largest" "planet with the famous" "Great Red Spot storm.")]
    [(string=? name "Saturn")  (list "5.683 x 10^26 kg" "116,460 km" "-140 C" "Gas giant famous for" "its complex ring system" "made of ice and rock.")]
    [(string=? name "Uranus")  (list "8.681 x 10^25 kg" "50,724 km" "-195 C" "Ice giant." "It rotates on its side" "unlike other planets.")]
    [(string=? name "Neptune") (list "1.024 x 10^26 kg" "49,244 km" "-200 C" "The windiest planet." "Dark, cold, and with" "supersonic winds.")]
    [else (list "?" "?" "?" "No Data" "Available" ".")]))

; Tests
(check-expect (first (get-planet-info "Earth")) "5.972 x 10^24 kg")
(check-expect (get-planet-info "Pluto") (list "?" "?" "?" "No Data" "Available" "."))
(check-expect (third (get-planet-info "Mars")) "-65 C")

;; Input/output
; get-gallery-image : String Number -> Image
; Returns the photo from the PRE-LOADED gallery lists based on index (1, 2, 3)
; header: (define (get-gallery-image name idx) Image) 

(define (get-gallery-image name idx)
  (local [
          ; Select the correct list of photos
          (define gallery-list
            (cond
              [(string=? name "Sun") GAL-SUN]
              [(string=? name "Mercury") GAL-MERCURY]
              [(string=? name "Venus") GAL-VENUS]
              [(string=? name "Earth") GAL-EARTH]
              [(string=? name "Mars") GAL-MARS]
              [(string=? name "Jupiter") GAL-JUPITER]
              [(string=? name "Saturn") GAL-SATURN]
              [(string=? name "Uranus") GAL-URANUS]
              [(string=? name "Neptune") GAL-NEPTUNE]
              [else GAL-EARTH]))]
    
    ; Pick 1st, 2nd or 3rd image (list-ref uses 0-based index, so we do idx - 1)
    (list-ref gallery-list (- idx 1))))


; -----------------------------
; 4. MISSIONS
; -----------------------------

;; Input/output
; predict-planet-position : CelestialBody Number -> Location
; Predicts the (x, y) location of a planet after a given number of ticks
; header: (define (predict-planet-position planet ticks) Location)
(define (predict-planet-position planet ticks)
  (local [; Calculate the new angle based on angular speed * time
          (define future-angle (+ (celestial-body-angle planet)
                                  (* (celestial-body-angular-speed planet) ticks)))
          (define orbit-radius (celestial-body-orbit-au planet))]
    ; Convert polar (angle, radius) to Cartesian (x, y)
    (make-location (* orbit-radius (cos future-angle))
                   (* orbit-radius (sin future-angle)))))

; Tests
(check-expect (location-x (predict-planet-position (make-celestial-body "Test" 10 100 "red" 0 0 '()) 10)) 100)
(check-within (location-y (predict-planet-position (make-celestial-body "Test" 10 100 "red" 0 0 '()) 10)) 0 0.001)

;; Input/output
; calculate-intercept-trajectory : CelestialBody CelestialBody Number -> (list Number Number Number)
; Calculates the velocity vector (vx, vy) and travel time to intercept a moving target
; Returns: (list vx vy travel-time)
; header: (define (calculate-intercept-trajectory from-planet to-planet speed-mult) (list Number Number Number))
(define (calculate-intercept-trajectory from-planet to-planet speed-mult)
  (local [(define from-loc (angle-to-location from-planet))
          (define to-angle (celestial-body-angle to-planet))
          (define to-orbit (celestial-body-orbit-au to-planet))
          (define to-angular-speed (celestial-body-angular-speed to-planet))
          ; Adjust angular speed by simulation speed multiplier
          (define actual-angular-speed (* to-angular-speed speed-mult)) 
          ; Constants for probe physics
          (define base-speed 2.5)
          (define probe-speed base-speed)
          ; Initial Euclidean distance calculation
          (define dx0 (- (* to-orbit (cos to-angle)) (location-x from-loc)))
          (define dy0 (- (* to-orbit (sin to-angle)) (location-y from-loc)))
          (define initial-distance (sqrt (+ (* dx0 dx0) (* dy0 dy0))))
          ; Initial guess for time: Distance / Speed
          (define estimated-time (/ initial-distance probe-speed))
          
          ; refine-trajectory : Number Number -> Number
          ; Iteratively improves the estimated travel time to account for target movement
          (define (refine-trajectory t iterations)
            (if (= iterations 0)
                t
                (local [; Where will the target be after time 't'?
                        (define future-angle (+ to-angle (* actual-angular-speed t)))
                        (define future-x (* to-orbit (cos future-angle)))
                        (define future-y (* to-orbit (sin future-angle)))
                        ; Calculate distance to that future point
                        (define dx (- future-x (location-x from-loc)))
                        (define dy (- future-y (location-y from-loc)))
                        (define actual-dist (sqrt (+ (* dx dx) (* dy dy))))
                        ; New time estimate
                        (define new-time (/ actual-dist probe-speed))]
                  (refine-trajectory new-time (- iterations 1)))))
          ; Run the refinement 5 times for accuracy
          (define final-time (refine-trajectory estimated-time 5))
          ; Calculate final target position based on refined time
          (define final-angle (+ to-angle (* actual-angular-speed final-time)))
          (define final-x (* to-orbit (cos final-angle)))
          (define final-y (* to-orbit (sin final-angle)))
          ; Vector math for velocity
          (define dx (- final-x (location-x from-loc)))
          (define dy (- final-y (location-y from-loc)))
          (define final-dist (sqrt (+ (* dx dx) (* dy dy))))
          
          (define vx (* probe-speed (/ dx final-dist)))
          (define vy (* probe-speed (/ dy final-dist)))]
    
    (list vx vy final-time)))

;; Input/output
; create-intercepting-probe : CelestialBody CelestialBody Number Number -> Probe
; Creates a new Probe struct initialized with position and velocity to intercept the target
; header: (define (create-intercepting-probe from-planet to-planet current-time speed-mult) Probe)
(define (create-intercepting-probe from-planet to-planet current-time speed-mult)
  (local [(define start-loc (angle-to-location from-planet))
          ; Get the calculated velocity and time
          (define trajectory (calculate-intercept-trajectory from-planet to-planet speed-mult))
          (define vx (first trajectory))
          (define vy (second trajectory))
          (define eta (third trajectory))]
    (make-probe 
     (location-x start-loc)
     (location-y start-loc)
     vx
     vy
     100             ; Start with 100% fuel
     "in-transit"    ; Initial status
     (celestial-body-name from-planet)
     (celestial-body-name to-planet)
     current-time)))

;; Input/output
; update-probe-smart : Probe Number List<CelestialBody> -> Probe
; Updates the position of a single probe based on its velocity and decreases fuel
; header: (define (update-probe-smart p speed-mult bodies) Probe)
; Template:
; (define (update-probe-smart p mult bodies)
;   (if (active? p) (make-probe ...) p))
(define (update-probe-smart p speed-mult bodies)
  (if (or (string=? (probe-status p) "in-transit")
          (string=? (probe-status p) "launching"))
      (make-probe 
       (+ (probe-x p) (probe-vx p))    ; New X = Old X + Velocity X
       (+ (probe-y p) (probe-vy p))    ; New Y = Old Y + Velocity Y
       (probe-vx p)
       (probe-vy p)
       (max 0 (- (probe-fuel p) 0.01)) ; Burn fuel
       "in-transit"
       (probe-departure-planet p)
       (probe-target-planet p)
       (probe-launch-time p))
      p))

; Tests
; Define a probe at (0,0) moving (5,5) pixels per tick with 100 fuel
(define MOVING-PROBE (make-probe 0 0 5 5 100 "in-transit" "A" "B" 0))
; Test 1: Check X position update (0 + 5 = 5)
(check-expect (probe-x (update-probe-smart MOVING-PROBE 1 '())) 5)
; Test 2: Check Y position update (0 + 5 = 5)
(check-expect (probe-y (update-probe-smart MOVING-PROBE 1 '())) 5)
; Test 3: Check Fuel consumption (100 - 0.01 = 99.99)
(check-within (probe-fuel (update-probe-smart MOVING-PROBE 1 '())) 99.99 0.001)
; Test 4: An 'arrived' probe should NOT move
(define STOPPED-PROBE (make-probe 100 100 5 5 50 "arrived" "A" "B" 0))
(check-expect (probe-x (update-probe-smart STOPPED-PROBE 1 '())) 100)

;; Input/output
; check-arrival-dynamic : Probe List<CelestialBody> -> Probe
; Checks if a probe is close enough to its target planet to be considered "arrived"
; header: (define (check-arrival-dynamic p bodies) Probe)
(define (check-arrival-dynamic p bodies)
  (if (or (string=? (probe-status p) "in-transit")
          (string=? (probe-status p) "launching"))
      (local [(define target (find-body-by-name bodies (probe-target-planet p)))
              (define target-loc (angle-to-location target))
              ; Distance formula (Pythagoras) between Probe and Target
              (define dx (- (probe-x p) (location-x target-loc)))
              (define dy (- (probe-y p) (location-y target-loc)))
              (define dist (sqrt (+ (* dx dx) (* dy dy))))
              ; change the number as "offset" for when the probe arrives
              (define arrival-radius 40)]
        (if (< dist arrival-radius)
            ; STOP the probe (velocity 0) and mark as ARRIVED
            (make-probe (probe-x p) (probe-y p) 0 0 (probe-fuel p)
                       "arrived"
                       (probe-departure-planet p)
                       (probe-target-planet p)
                       (probe-launch-time p))
            p))
      p))

; Tests
; Target planet is at Distance 100, Angle 0. So location is (100, 0)
(define TEST-TARGET (make-celestial-body "Target" 10 100 "red" 0 0 '()))
(define TEST-SYSTEM (list TEST-TARGET))
; Case 1: Probe is FAR away (at x=200). Distance is 100. Should NOT arrive
(define PROBE-FAR (make-probe 200 0 -1 0 100 "in-transit" "Origin" "Target" 0))
(check-expect (probe-status (check-arrival-dynamic PROBE-FAR TEST-SYSTEM)) "in-transit")

; Case 2: Probe is CLOSE (at x=110). Distance is 10. Should ARRIVE
; (Hitbox is 40 pixels).
(define PROBE-CLOSE (make-probe 110 0 -1 0 100 "in-transit" "Origin" "Target" 0))
(check-expect (probe-status (check-arrival-dynamic PROBE-CLOSE TEST-SYSTEM)) "arrived")

; Case 3: Verify velocity becomes 0 when arrived
(check-expect (probe-vx (check-arrival-dynamic PROBE-CLOSE TEST-SYSTEM)) 0)

;; Input/output
; update-missions-smart : List<Mission> List<CelestialBody> Number -> List<Mission>
; Updates the state of all active missions, moving probes and checking for arrival
; header: (define (update-missions-smart missions bodies speed-mult) List<Mission>)
; Template: (Standard recursive list processing)
; (define (update-missions-smart l ...)
;   (cond [(empty? l) ...]
;         [else (... (first l) ... (update-missions-smart (rest l) ...))]))
(define (update-missions-smart missions bodies speed-mult)
  (cond [(empty? missions) '()]
        [else (local [(define m (first missions))
                      (define p (mission-probe m))]
                (if (probe? p)
                    ; 1. Move the probe -> 2. Check if it hit the target -> 3. Update Status
                    (local [(define updated-probe (check-arrival-dynamic 
                                                   (update-probe-smart p speed-mult bodies) 
                                                   bodies))
                            (define new-status (if (string=? (probe-status updated-probe) "arrived")
                                                   "completed"
                                                   (mission-status m)))]
                      (cons (make-mission (mission-departure m)
                                         (mission-target m)
                                         new-status
                                         updated-probe)
                            (update-missions-smart (rest missions) bodies speed-mult)))
                    ; If no probe exists yet, keep mission as is
                    (cons m (update-missions-smart (rest missions) bodies speed-mult))))]))

;; Input/output
; draw-intercept-trajectory : CelestialBody CelestialBody Location Number Number Image -> Image
; Draws a dashed line representing the calculated future path of the probe
; header: (define (draw-intercept-trajectory from-planet to-planet target-loc zoom speed-mult scene) Image)
(define (draw-intercept-trajectory from-planet to-planet target-loc zoom speed-mult scene)
  (local [(define trajectory (calculate-intercept-trajectory from-planet to-planet speed-mult))
          (define travel-time (third trajectory))
          (define from-loc (angle-to-location from-planet))
          (define future-target-loc (predict-planet-position to-planet travel-time))
          ; Calculate screen coordinates relative to camera
          (define x1 (+ CENTER-X (* (- (location-x from-loc) (location-x target-loc)) zoom)))
          (define y1 (+ CENTER-Y (* (- (location-y from-loc) (location-y target-loc)) zoom)))
          (define x2 (+ CENTER-X (* (- (location-x future-target-loc) (location-x target-loc)) zoom)))
          (define y2 (+ CENTER-Y (* (- (location-y future-target-loc) (location-y target-loc)) zoom)))]
    
    (scene+line scene x1 y1 x2 y2 (make-pen "cyan" 2 "long-dash" "round" "round"))))

;; Input/output
; draw-probe-with-trail : Probe Location Number Image -> Image
; Draws a probe as a rotated triangle with a fading trail behind it
; header: (define (draw-probe-with-trail p target-loc zoom scene) Image)
(define (draw-probe-with-trail p target-loc zoom scene)
  (local [(define draw-x (+ CENTER-X (* (- (probe-x p) (location-x target-loc)) zoom)))
          (define draw-y (+ CENTER-Y (* (- (probe-y p) (location-y target-loc)) zoom)))
          
          ; Calculate rotation angle for icon
          (define angle-rad (atan (probe-vy p) (probe-vx p)))
          (define angle-deg (* angle-rad (/ 180 pi)))
          
          ; Visual Elements
          (define probe-icon (rotate (- 90 angle-deg) (triangle 10 "solid" "lime")))
          
          ; Trail Logic
          (define trail-length 25)
          (define trail-x (- draw-x (* (probe-vx p) trail-length zoom)))
          (define trail-y (- draw-y (* (probe-vy p) trail-length zoom)))]
    
    (place-image probe-icon draw-x draw-y
                 (scene+line scene trail-x trail-y draw-x draw-y 
                            (make-pen (color 0 255 0 120) 4 "solid" "round" "round")))))

;; Input/output
; draw-all-active-probes : List<Mission> Location Number Image -> Image
; Recursively draws all probes currently in "launching" or "in-transit" status
; header: (define (draw-all-active-probes missions target-loc zoom scene) Image)
(define (draw-all-active-probes missions target-loc zoom scene)
  (cond [(empty? missions) scene]
        [else (local [(define m (first missions))
                      (define p (mission-probe m))]
                (if (and (probe? p)
                         (or (string=? (probe-status p) "launching")
                             (string=? (probe-status p) "in-transit")))
                    (draw-all-active-probes (rest missions) target-loc zoom 
                                           (draw-probe-with-trail p target-loc zoom scene))
                    (draw-all-active-probes (rest missions) target-loc zoom scene)))]))

;; Input/output
; launch-intercept-mission : SimState String String -> SimState
; Initiates a mission: creates the probe and adds it to the active missions list
; header: (define (launch-intercept-mission state departure target) SimState)
(define (launch-intercept-mission state departure target)
  (local [(define bodies (sim-state-bodies state))
          (define from-planet (find-body-by-name bodies departure))
          (define to-planet (find-body-by-name bodies target))
          (define current-idx (sim-state-speed-index state))
          (define speed-mult (second (list-ref SPEED-LEVELS current-idx)))
          ; Create the probe with calculated physics
          (define new-probe (create-intercepting-probe from-planet to-planet 
                                                       (sim-state-sim-time state)
                                                       speed-mult))
          ; Wrap it in a Mission struct
          (define new-mission (make-mission departure target "active" new-probe))
          ; Add to the list of active missions
          (define updated-missions (cons new-mission (sim-state-active-missions state)))]
    (make-sim-state 
     bodies
     (sim-state-zoom state)
     (sim-state-mouse-x state)
     (sim-state-mouse-y state)
     (sim-state-locked-body-name state)
     (sim-state-speed-index state)
     (sim-state-active-tab state)
     (sim-state-gallery-index state)
     (sim-state-asteroid-belt state)
     (sim-state-active-comets state)
     updated-missions
     "none"
     ""
     (sim-state-sim-time state)
     (sim-state-day-counter state))))

; -----------------------------
; 5. GENERATORS
; -----------------------------

;; Input/output
; generate-asteroids : Number -> List<Asteroid>
; Creates a list of N asteroids with random properties
; header: (define (generate-asteroids n) List<Asteroid>)
; template:
; (define (generate-asteroids n)
;   (cond
;     [(= n 0) '()]
;      [else
;       (cons (make-asteroid ...) 
;            (generate-asteroids (- n 1)))]))

(define (generate-asteroids n)
  (cond
    [(= n 0) '()]
    [else
     (cons (make-asteroid 
            (random 360) (+ 460 (random 70)) 
            (* (+ 0.3 (/ (random 100) 100)) SPEED-SCALE)
            (+ 1 (random 3)) (if (= (random 2) 0) "gray" "dim gray")) 
           (generate-asteroids (- n 1)))]))

 
;; Input/output
; generate-stars : Number Image -> Image
; Recursively draws white dots on a background to simulate stars.
; header: (define (generate-stars n scene) Image)
; template:
; (define (generate-stars n scene)
;   (cond [(= n 0) scene] 
;         [else
;          (place-image ...
;           (generate-stars (- n 1) scene))]))

(define (generate-stars n scene)
  (cond [(= n 0) scene] 
        [else
         (place-image
          (circle (max 1 (random 3)) "solid" "white")  ; Random size (1 or 2 pixels)
          (random SCENE-WIDTH)                         ; Random x
          (random SCENE-HEIGHT)                        ; Random y
          (generate-stars (- n 1) scene))]))           ; Recursive case


(define BLACK-BACKGROUND (empty-scene SCENE-WIDTH SCENE-HEIGHT "black"))
(define EMPTY-SCENE (generate-stars 200 BLACK-BACKGROUND))  ; Final scene with 200 stars

; -----------------------------
; 6. INITIALIZATION
; ----------------------------- 

(define SUN  (make-celestial-body "Sun" 45 0 "yellow" 0 0 '())) 
(define MERCURY (make-celestial-body "Mercury" 4 (* 1 ORBIT-STEP) "gray" 0 (* 4.17 SPEED-SCALE) '()))
(define VENUS  (make-celestial-body "Venus" 8 (* 2 ORBIT-STEP) "orange" 1 (* 1.61 SPEED-SCALE) '()))
(define EARTH  (make-celestial-body "Earth" 9 (* 3 ORBIT-STEP) "blue" 2 (* 1.00 SPEED-SCALE) (list (make-moon "Moon" 6 55 "white" 0.12)))) 
(define MARS   (make-celestial-body "Mars" 6 (* 4 ORBIT-STEP) "red" 3 (* 0.53 SPEED-SCALE) (list (make-moon "Phobos" 4 30 "gray" 0.20) (make-moon "Deimos" 3 45 "gray" 0.15))))
(define JUPITER (make-celestial-body "Jupiter" 16 (* 5 ORBIT-STEP) "sienna" 4 (* 0.084 SPEED-SCALE) (list (make-moon "Io" 5 50 "yellow" 0.20) (make-moon "Europa" 5 65 "white" 0.15) (make-moon "Ganymede" 7 80 "gray" 0.10) (make-moon "Callisto" 6 95 "brown" 0.05))))
(define SATURN (make-celestial-body "Saturn" 14 (* 6 ORBIT-STEP) "gold" 5 (* 0.034 SPEED-SCALE) (list (make-moon "Titan" 7 80 "orange" 0.10))))
(define URANUS (make-celestial-body "Uranus" 12 (* 7 ORBIT-STEP) "lightblue" 6 (* 0.012 SPEED-SCALE) '()))
(define NEPTUNE (make-celestial-body "Neptune" 11 (* 8 ORBIT-STEP) "navy" 0.5 (* 0.006 SPEED-SCALE) '()))

(define INITIAL-ASTEROIDS (generate-asteroids 400)) 
(define INITIAL-SOLAR-SYSTEM (list SUN MERCURY VENUS EARTH MARS JUPITER SATURN URANUS NEPTUNE))

; Note: gallery-index starts at 1
(define INITIAL-STATE 
  (make-sim-state 
   INITIAL-SOLAR-SYSTEM  ; bodies
   0.7                   ; zoom
   0 0                   ; mouse-x, mouse-y
   "Sun"                 ; locked-body-name
   4                     ; speed-index
   "STATS"               ; active-tab
   1                     ; gallery-index
   INITIAL-ASTEROIDS     ; asteroid-belt
   '()                   ; active-comets
   '()                   ; active-missions 
   "none"                ; mission-mode 
   ""                    ; selected-departure 
   0                     ; sim-time
   345))                 ; day-counter


; -----------------------------
; 7. PHYSICS & UPDATES
; -----------------------------

;; Input/output
; next-satellite-state : Satellite Number -> Satellite
; Updates the angle of a single satellite based on speed
; header: (define (next-satellite-state moon speed-mult) Satellite)

(define (next-satellite-state moon speed-mult)
  (make-satellite (satellite-name moon)
                  (satellite-radius moon)
                  (satellite-dist moon)
                  (satellite-color moon)
                  (+ (satellite-angle moon) (* (satellite-speed moon) speed-mult))
                  (satellite-speed moon)))

; Tests
(define TEST-MOON (make-satellite "Moon" 5 100 "white" 0 2))
(check-expect (next-satellite-state TEST-MOON 1) (make-satellite "Moon" 5 100 "white" 2 2))
(check-expect (next-satellite-state TEST-MOON 0.5) (make-satellite "Moon" 5 100 "white" 1 2)) 

;; Input/output
; update-satellites : List<Satellite> Number -> List<Satellite>
; Updates a list of satellites
; header: (define (update-satellites moons speed-mult) List<Satellite>)

(define (update-satellites moons speed-mult)
  (cond [(empty? moons) '()] 
        [else (cons (next-satellite-state (first moons) speed-mult) 
                    (update-satellites (rest moons) speed-mult))]))

;; Input/output
; next-body-state : CelestialBody Number -> CelestialBody
; Updates a planet's angle and recursively updates its satellites
; header: (define (next-body-state body speed-mult) CelestialBody)

(define (next-body-state body speed-mult)
  (make-celestial-body (celestial-body-name body)
                       (celestial-body-radius body)
                       (celestial-body-orbit-au body)
                       (celestial-body-color body)
                       (+ (celestial-body-angle body) (* (celestial-body-angular-speed body) speed-mult))
                       (celestial-body-angular-speed body)
                       (update-satellites (celestial-body-satellites body) speed-mult)))

; Tests
(check-expect (celestial-body-angle (next-body-state (make-celestial-body "T" 1 1 "c" 0 0.1 '()) 1)) 0.1)

;; Input/output
; next-asteroid : Asteroid Number -> Asteroid
; Updates the angle of an asteroid.
; header: (define (next-asteroid ast speed-mult) Asteroid)

(define (next-asteroid ast speed-mult)
  (make-asteroid (+ (asteroid-angle ast) (* (asteroid-speed ast) speed-mult)) 
                 (asteroid-dist ast)
                 (asteroid-speed ast)
                 (asteroid-size ast)
                 (asteroid-color ast)))

; Tests
(define TEST-AST (make-asteroid 100 500 5 2 "gray"))
(check-expect (next-asteroid TEST-AST 0) (make-asteroid 100 500 5 2 "gray"))
(check-expect (next-asteroid TEST-AST 2) (make-asteroid 110 500 5 2 "gray"))

;; Input/output
; update-asteroids : List<Asteroid> Number -> List<Asteroid>
; Updates list of asteroids.
; header: (define (update-asteroids asteroids speed-mult) List<Asteroid>)

(define (update-asteroids asteroids speed-mult)
  (cond [(empty? asteroids) '()] 
        [else (cons (next-asteroid (first asteroids) speed-mult)
                    (update-asteroids (rest asteroids) speed-mult))]))

;; Input/output
; next-comet : Comet -> Comet
; Updates comet position (x, y) based on velocity (vx, vy)
; header: (define (next-comet c) Comet)

(define (next-comet c)
  (make-comet (+ (comet-x c) (comet-vx c))
              (+ (comet-y c) (comet-vy c))
              (comet-vx c)
              (comet-vy c)
              (comet-size c)))

; Tests
(define TEST-COMET (make-comet 100 100 5 -2 10))
(check-expect (next-comet TEST-COMET) (make-comet 105 98 5 -2 10))
(check-expect (next-comet (make-comet 50 50 0 0 5)) (make-comet 50 50 0 0 5))

;; Input/output
; filter-comets : List<Comet> -> List<Comet>
; Removes comets that have moved far off the screen boundaries
; header: (define (filter-comets comets) List<Comet>)

(define (filter-comets comets)
  (cond [(empty? comets) '()]
        [else (local [; Comet
                      ; The first comet in the list
                      (define c (first comets))]
                (if (or (< (comet-x c) -200) (> (comet-x c) (+ SCENE-WIDTH 200))
                        (< (comet-y c) -200) (> (comet-y c) (+ SCENE-HEIGHT 200)))
                    (filter-comets (rest comets))
                    (cons (next-comet c)
                          (filter-comets (rest comets)))))]))

; Tests
(define C-GOOD (make-comet 500 500 0 0 5))
(define C-BAD (make-comet -300 500 0 0 5))
(check-expect (filter-comets (list C-GOOD)) (list C-GOOD))
(check-expect (filter-comets (list C-GOOD C-BAD)) (list C-GOOD))



;; Input/output
; maybe-spawn-comet : List<Comet> -> List<Comet>
; Randomly adds a new comet with a very low probability (2 in 3000 chance)
; header: (define (maybe-spawn-comet current-comets) List<Comet>)
; Template:
; (define (maybe-spawn-comet comets)
;   (if (< (random 3000) 2)
;       (cons (make-comet ...) current-comets)
;       current-comets))

(define (maybe-spawn-comet current-comets)
  (if (< (random 3000) 2) 
      (cons (make-comet -100
                        (random SCENE-HEIGHT)
                        (+ 2 (random 5))
                        (- (random 3) 1.5)
                        (+ 2 (random 3)))
            current-comets)
      current-comets))

;; Input/output
; next-world : SimState -> SimState
; The main clock tick function. Updates bodies, asteroids, comets, and handles spawning
; header: (define (next-world current-state) SimState) 
(define (next-world current-state)
  (local [
          ; Number
          (define current-idx (sim-state-speed-index current-state))
          ; Number
          (define speed-mult (second (list-ref SPEED-LEVELS current-idx)))
          ; List<CelestialBody>
          (define bodies (sim-state-bodies current-state))
          ; List<Asteroid>
          (define asteroids (sim-state-asteroid-belt current-state))
          ; List<Comets>
          (define comets (sim-state-active-comets current-state))
          ; Time update
          (define current-days (sim-state-day-counter current-state))
          (define next-days (+ current-days (* speed-mult 0.2)))
          (define missions (sim-state-active-missions current-state))
          (define current-time (sim-state-sim-time current-state))

          ; update-bodies : List<CelestialBody> -> List<CelestialBody>
          ; Updates position/angle of all bodies based on speed-mult
          (define (update-bodies bodies)
            (cond [(empty? bodies) '()] 
                  [else (cons (next-body-state (first bodies) speed-mult)
                              (update-bodies (rest bodies)))]))]
    
    (make-sim-state 
     (update-bodies bodies)
     (sim-state-zoom current-state)
     (sim-state-mouse-x current-state)
     (sim-state-mouse-y current-state)
     (sim-state-locked-body-name current-state)
     (sim-state-speed-index current-state)
     (sim-state-active-tab current-state)
     (sim-state-gallery-index current-state) 
     (update-asteroids asteroids speed-mult)
     (maybe-spawn-comet (filter-comets comets))
     (update-missions-smart missions bodies speed-mult)      
     (sim-state-mission-mode current-state)  
     (sim-state-selected-departure current-state) 
     (+ current-time 1)
     next-days)))                   
 
; -----------------------------
; 8. DRAWING LOGIC 
; -----------------------------

;; Input/output
; draw-satellites-for-planet : List<Satellite> Number Number Number Image -> Image
; Draws satellites around a specific planet's x/y coordinates
; header: (define (draw-satellites-for-planet moons planet-x planet-y zoom scene) Image)

(define (draw-satellites-for-planet moons planet-x planet-y zoom scene)
  (cond [(empty? moons) scene]
        [else (local [; Satellite
                      (define moon (first moons))
                      ; Number (screen x coordinate)
                      (define mx (+ planet-x (* (satellite-dist moon) zoom (cos (satellite-angle moon)))))
                      ; Number (screen y coordinate)
                      (define my (+ planet-y (* (satellite-dist moon) zoom (sin (satellite-angle moon)))))
                      ; Image
                      (define moon-img (circle (max 2 (* zoom (satellite-radius moon))) "solid" (satellite-color moon)))]
                (draw-satellites-for-planet (rest moons) planet-x planet-y zoom (place-image moon-img mx my scene)))]))

;; Input/output
; draw-celestial-body : CelestialBody Location String Number Number Number Image -> Image
; Draws a single planet, including its orbit line (if applicable), image, hover highlight, and moons
; header: (define (draw-celestial-body body target-loc locked-name zoom mx my scene) Image)

(define (draw-celestial-body body target-loc locked-name zoom mx my scene)
  (local [; Location (Cartesian coordinates of body)
          (define loc (angle-to-location body))
          ; Number
          (define radius-orbit (celestial-body-orbit-au body)) 
          (define zoomed-orbit-radius (* radius-orbit zoom))
          ; Number (x coordinate relative to camera target)
          (define relative-x (- (location-x loc) (location-x target-loc)))
          ; Number (y coordinate relative to camera target) 
          (define relative-y (- (location-y loc) (location-y target-loc)))
          (define orbit-img (circle (max 1 zoomed-orbit-radius) "outline" (color 255 255 255 50)))
          ; Draw orbit only if looking at Sun
          (define scene-with-orbit (if (and (> radius-orbit 0) (string=? locked-name "Sun")) (place-image orbit-img CENTER-X CENTER-Y scene) scene))
          (define planet-base-image (cond
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
          ; Number (final screen x)
          (define x (+ CENTER-X (* relative-x zoom)))
          ; Number (final screen y)
          (define y (+ CENTER-Y (* relative-y zoom)))
          (define distance (sqrt (+ (sqr (- mx x)) (sqr (- my y)))))
          (define highlight (if (< distance (/ (image-width (scale zoom planet-base-image)) 2)) 
                                (circle (+ (/ (image-width (scale zoom planet-base-image)) 2) 5) "outline" "white") empty-image))
          ; Image (final composition)
          (define scene-planet (place-image (scale zoom planet-base-image) x y (place-image highlight x y scene-with-orbit)))]
    
    (if (string=? locked-name (celestial-body-name body)) 
        (draw-satellites-for-planet (celestial-body-satellites body) x y zoom scene-planet) 
        scene-planet)))

;; Input/output
; draw-all-bodies : List<CelestialBody> Location String Number Number Number Image -> Image
; Recursively draws all planets in the list
; header: (define (draw-all-bodies bodies target-loc locked-name zoom mx my scene) Image)

(define (draw-all-bodies bodies target-loc locked-name zoom mx my scene)
  (cond [(empty? bodies) scene] 
        [else (draw-all-bodies (rest bodies) target-loc locked-name zoom mx my 
                               (draw-celestial-body (first bodies) target-loc locked-name zoom mx my scene))]))

;; Input/output
; draw-asteroids : List<Asteroid> Location Number Image -> Image
; Draws the asteroid belt relative to the camera position
; header: (define (draw-asteroids asteroids target-loc zoom scene) Image)

(define (draw-asteroids asteroids target-loc zoom scene)
  (cond [(empty? asteroids) scene]
        [else (local [; Asteroid
                      (define ast (first asteroids))
                      ; Number (calculated screen X)
                      (define mx (+ CENTER-X (* (- (* (asteroid-dist ast) (cos (asteroid-angle ast))) (location-x target-loc)) zoom)))
                      ; Number (calculated screen Y)
                      (define my (+ CENTER-Y (* (- (* (asteroid-dist ast) (sin (asteroid-angle ast))) (location-y target-loc)) zoom)))]
                (draw-asteroids (rest asteroids) target-loc zoom (place-image (circle (max 1 (* zoom (asteroid-size ast))) "solid" (asteroid-color ast)) mx my scene)))]))

;; Input/output
; draw-comets : List<Comet> Number Image -> Image
; Draws comets with a simple trail effect
; header: (define (draw-comets comets zoom scene) Image)

(define (draw-comets comets zoom scene)
  (cond [(empty? comets) scene]
        [else (local [; Comet
                      (define c (first comets))
                      ; Number
                      (define draw-x (+ CENTER-X (* (- (comet-x c) CENTER-X) zoom)))
                      ; Number 
                      (define draw-y (+ CENTER-Y (* (- (comet-y c) CENTER-Y) zoom)))
                      ; Image
                      (define head (circle (max 2 (* zoom (comet-size c))) "solid" "white"))
                      ; Image
                      (define tail (line (* -5 (comet-vx c) zoom) (* -5 (comet-vy c) zoom) (color 255 255 255 100)))]
                (draw-comets (rest comets) zoom (place-image head draw-x draw-y (place-image tail draw-x draw-y scene))))]))

;; Input/output
; draw-interface : String String String Number Image -> Image
; Draws the HUD, Legend, and Info Panel (Stats, Info, Photos)
; header: (define (draw-interface locked-name speed-label tab gal-idx scene) Image)

(define (draw-interface locked-name speed-label tab gal-idx day-count mission-mode scene)
  (local [; List<String>
          (define info-list (get-planet-info locked-name))
          ; String (extracted data)
          (define mass (first info-list)) (define diam (second info-list)) (define temp (third info-list))
          (define desc1 (fourth info-list)) (define desc2 (fifth info-list)) (define desc3 (sixth info-list))
          
          (define stats-color (if (string=? tab "STATS") "cornflowerblue" "gray"))
          (define info-color  (if (string=? tab "INFO")  "cornflowerblue" "gray"))
          (define phot-color  (if (string=? tab "PHOTOS") "cornflowerblue" "gray")) 
          
          ; ARROW IMAGES DEFINITION (Used for both drawing and hit-box logic consistency)
          (define ARROW-LEFT (overlay (text "<" 20 "white") (square 30 "solid" "gray")))
          (define ARROW-RIGHT (overlay (text ">" 20 "white") (square 30 "solid" "gray")))

          ; Convert exact day count to integer
          (define total-days (floor day-count))
          ; Calculate Year (starting from 2025)
          (define current-year (+ 2025 (floor (/ total-days 365))))
          ; Calculate Day of Year (0-364)
          (define current-day (modulo total-days 365))

          ; Image
          ; The content displayed inside the main panel based on the active tab
          (define content-text
            (cond
              [(string=? tab "STATS")
               (above/align "left"
                            (text (string-append "Mass: " mass) 14 "white")
                            (text " " 8 "black")
                            (text (string-append "Diameter: " diam) 14 "white")
                            (text " " 8 "black")
                            (text (string-append "Temperature: " temp) 14 "white"))]
              [(string=? tab "INFO")
               (above/align "center"
                            (text desc1 14 "white")
                            (text " " 4 "transparent")
                            (text desc2 14 "white")
                            (text " " 4 "transparent")
                            (text desc3 14 "white"))]
              [(string=? tab "PHOTOS")
               (local [
                       (define current-photo (get-gallery-image locked-name gal-idx))
                       ; SCALE TO FIT LOGIC (Letterboxing)
                       ; 1. Calculate scale factors for width and height
                       (define scale-w (/ GALLERY-VIEW-WIDTH (image-width current-photo)))
                       (define scale-h (/ GALLERY-VIEW-HEIGHT (image-height current-photo)))
                       ; 2. Use the smaller factor to ensure it fits entirely
                       (define final-scale (min scale-w scale-h))
                       (define scaled-img (scale final-scale current-photo))
                       ; 3. Center on fixed-size background
                       (define disp-img (overlay scaled-img (rectangle GALLERY-VIEW-WIDTH GALLERY-VIEW-HEIGHT "solid" "black")))]
                 (above
                  disp-img
                  (text " " 10 "transparent")
                  (text (string-append "Img " (number->string gal-idx) "/3") 14 "white")))]))
          
          (define info-panel-bg (rectangle PANEL-WIDTH PANEL-HEIGHT "solid" (color 0 0 50 220)))
          ; Image (Composed panel components)
          (define buttons-row
            (beside (overlay (text "STATS" 12 "white") (rectangle BUTTON-WIDTH BUTTON-HEIGHT "solid" stats-color)) 
                    (overlay (text "INFO" 12 "white")  (rectangle BUTTON-WIDTH BUTTON-HEIGHT "solid" info-color))
                    (overlay (text "PHOTOS" 12 "white") (rectangle BUTTON-WIDTH BUTTON-HEIGHT "solid" phot-color))))
          
          ; Base Panel with content (without arrows)
          (define base-panel 
            (overlay/align "middle" "top"
                           (above buttons-row
                                  (rectangle 1 15 "solid" "transparent")
                                  (text (string-upcase locked-name) 22 "yellow")
                                  (rectangle 1 15 "solid" "transparent") content-text)
                           info-panel-bg))
          
          (define hud (above/align "left"
                                   (text (string-append "Camera: " locked-name) 16 "white")
                                   (text "" 2 "black")
                                   (text (string-append "Speed: " speed-label) 16 "white")
                                   ; Display date
                                   (text "" 2 "black")
                                   (text (string-append "Year: " (number->string current-year)) 16 "yellow")
                                   (text "" 2 "black")
                                   (text (string-append "Day: " (number->string current-day)) 16 "yellow")))
          (define legend (above/align "left"
                                      (text "LEGEND" 16 "yellow") 
                                      (text "" 5 "black")
                                      (text "Arrows: Zoom" 14 "white")
                                      (text "" 5 "black")
                                      (text "I / D: Speed" 14 "white")
                                      (text "" 5 "black")
                                      (text "Click: Lock" 14 "white")
                                      (text "" 5 "black")
                                      (text "M: Mission" 14 "white")
                                      (text "" 5 "black")
                                      (text "R: Reset" 14 "white")))
          ; Top Right Mission Help
          (define mission-help (above/align "right"
                                            (text "MISSION" 16 "yellow")
                                            (text "" 5 "black")
                                            (text "1. Press 'M'" 14 "white")
                                            (text "" 5 "black")
                                            (text "2. Click Start Planet" 14 "white")
                                            (text "" 5 "black")
                                            (text "3. Click Target Planet" 14 "white")))
          
          ; If mission-mode is NOT "none", draw the scene WITH the help overlay; Otherwise, return the scene as is
          (define scene-with-help 
            (if (not (string=? mission-mode "none"))
                (place-image mission-help (- SCENE-WIDTH 130) 60 scene)
                scene))] 
    
    ; Place base panel
    (place-image base-panel (+ PANEL-X (/ PANEL-WIDTH 2)) (+ PANEL-Y (/ PANEL-HEIGHT 2))
                 ; IF PHOTOS tab, place ARROWS explicitly on top
                 (if (string=? tab "PHOTOS")
                     (place-image ARROW-LEFT (+ PANEL-X 60) (+ PANEL-Y 240)
                                  (place-image ARROW-RIGHT (+ PANEL-X 290) (+ PANEL-Y 240)
                                               (place-image hud 120 70 
                                                            (place-image legend 120 (- SCENE-HEIGHT 130) scene-with-help))))
                     ; ELSE just HUD
                     (place-image hud 120 70 
                                  (place-image legend 120 (- SCENE-HEIGHT 130) scene-with-help))))))

;; Input/output
; draw-world : SimState -> Image
; Main drawing function. It calculates the camera target and delegates to helper functions
; header: (define (draw-world current-state) Image)
(define (draw-world current-state)
  (local [
          ; List<CelestialBody>
          (define bodies (sim-state-bodies current-state))
          ; Number
          (define zoom (sim-state-zoom current-state))
          (define mx (sim-state-mouse-x current-state))
          (define my (sim-state-mouse-y current-state))
          (define locked-name (sim-state-locked-body-name current-state))
          (define idx (sim-state-speed-index current-state))
          (define tab (sim-state-active-tab current-state))
          (define gal (sim-state-gallery-index current-state))
          ; List<Asteroids>
          (define asteroids (sim-state-asteroid-belt current-state))
          ; List<Comets>
          (define comets (sim-state-active-comets current-state))
          (define day-cnt (sim-state-day-counter current-state))
          (define missions (sim-state-active-missions current-state))
          (define mission-mode (sim-state-mission-mode current-state))
          (define selected-dep (sim-state-selected-departure current-state))
          (define speed-label (first (list-ref SPEED-LEVELS idx)))
          ; CelestialBody (The object the camera follows)
          (define target-body (find-body-by-name bodies locked-name))
          ; Location (The coordinates of that object)
          (define target-loc (angle-to-location target-body))
          
          (define scene-with-trajectory
            (if (and (string=? mission-mode "selecting-target") (not (string=? selected-dep "")))
                (local [(define current-idx idx)
                        (define speed-mult (second (list-ref SPEED-LEVELS current-idx)))]
                  (draw-intercept-trajectory 
                   (find-body-by-name bodies selected-dep)
                   (find-body-by-name bodies locked-name)
                   target-loc zoom speed-mult
                   (draw-comets comets zoom
                     (draw-asteroids asteroids target-loc zoom 
                       (draw-all-bodies bodies target-loc locked-name zoom mx my EMPTY-SCENE)))))
                (draw-comets comets zoom
                   (draw-asteroids asteroids target-loc zoom 
                     (draw-all-bodies bodies target-loc locked-name zoom mx my EMPTY-SCENE)))))
          
          ; Image (The rendered universe without UI)
          (define space-scene (draw-all-active-probes missions target-loc zoom scene-with-trajectory))]
    
    (draw-interface locked-name speed-label tab gal day-cnt mission-mode space-scene)))

; -----------------------------
; 9. INPUT HANDLERS
; -----------------------------

;; Input/output
; handle-key : SimState String -> SimState
; Updates zoom, speed, or camera locking based on keyboard input
; header: (define (handle-key current-state key) SimState)

(define (handle-key current-state key)
  (local [
          ; Number
          (define current-zoom (sim-state-zoom current-state))
          ; List<CelestialBody>
          (define bodies (sim-state-bodies current-state))
          (define mx (sim-state-mouse-x current-state))
          (define my (sim-state-mouse-y current-state))
          (define locked (sim-state-locked-body-name current-state))
          (define idx (sim-state-speed-index current-state))
          (define tab (sim-state-active-tab current-state))
          (define gal (sim-state-gallery-index current-state))
          ; List<Asteroids>
          (define asteroids (sim-state-asteroid-belt current-state))
          ; List<Comets>
          (define comets (sim-state-active-comets current-state))
          (define missions (sim-state-active-missions current-state))
          (define mission-mode (sim-state-mission-mode current-state))
          (define selected-dep (sim-state-selected-departure current-state))
          (define sim-time (sim-state-sim-time current-state))
          (define days (sim-state-day-counter current-state))
          (define max-idx (- (length SPEED-LEVELS) 1))]
    
    (cond
      [(or (key=? key "up") (key=? key "="))             ; Zoom IN 
       (make-sim-state bodies (+ current-zoom 0.1) mx my locked idx tab gal asteroids comets missions mission-mode selected-dep sim-time days)]
      [(or (key=? key "down") (key=? key "-"))           ; Zoom OUT 
       (make-sim-state bodies (max 0.1 (- current-zoom 0.1)) mx my locked idx tab gal asteroids comets missions mission-mode selected-dep sim-time days)] 
      [(key=? key "i")                                   ; Increase speed
       (make-sim-state bodies current-zoom mx my locked (min max-idx (+ idx 1)) tab gal asteroids comets missions mission-mode selected-dep sim-time days)]
      [(key=? key "d")                                   ; Decrease speed
       (make-sim-state bodies current-zoom mx my locked (max 0 (- idx 1)) tab gal asteroids comets missions mission-mode selected-dep sim-time days)]
       [(key=? key "r") INITIAL-STATE]                   ; Full reset for year and day
      
      [(key=? key "m")
       (if (string=? mission-mode "none")
           (make-sim-state bodies current-zoom mx my locked idx tab gal 
                          asteroids comets missions 
                          "selecting-departure"
                          "" 
                          sim-time
                          days)
           (make-sim-state bodies current-zoom mx my locked idx tab gal 
                          asteroids comets missions 
                          "none" 
                          "" 
                          sim-time
                          days))]
      
      [else current-state])))

;; Input/output
; handle-mouse : SimState Number Number MouseEvent -> SimState
; Updates mouse position and handles clicks on UI buttons or planets
; header: (define (handle-mouse current-state x y event) SimState)
(define (handle-mouse current-state x y event)
  (local [; List<CelestialBody>
          (define bodies (sim-state-bodies current-state))
          (define zoom (sim-state-zoom current-state))
          (define locked-name (sim-state-locked-body-name current-state))
          (define idx (sim-state-speed-index current-state))
          (define tab (sim-state-active-tab current-state))
          (define gal (sim-state-gallery-index current-state))
          ; List<Asteroids>
          (define asteroids (sim-state-asteroid-belt current-state))
          ; List<Comets>
          (define comets (sim-state-active-comets current-state))
          (define missions (sim-state-active-missions current-state))
          (define mission-mode (sim-state-mission-mode current-state))
          (define selected-dep (sim-state-selected-departure current-state))
          (define sim-time (sim-state-sim-time current-state))
          (define day-counter (sim-state-day-counter current-state))
          ; Boolean (Hit detection for UI elements)
          (define click-in-panel? (and (> x PANEL-X) (< x (+ PANEL-X PANEL-WIDTH)) 
                                      (> y PANEL-Y) (< y (+ PANEL-Y PANEL-HEIGHT))))
          (define click-stats-btn? (and (> x PANEL-X) (< x (+ PANEL-X BUTTON-WIDTH)) 
                                       (> y PANEL-Y) (< y (+ PANEL-Y BUTTON-HEIGHT))))
          (define click-info-btn? (and (> x (+ PANEL-X BUTTON-WIDTH)) 
                                      (< x (+ PANEL-X (* 2 BUTTON-WIDTH))) 
                                      (> y PANEL-Y) (< y (+ PANEL-Y BUTTON-HEIGHT))))
          (define click-photo-btn? (and (> x (+ PANEL-X (* 2 BUTTON-WIDTH))) 
                                       (< x (+ PANEL-X PANEL-WIDTH)) 
                                       (> y PANEL-Y) (< y (+ PANEL-Y BUTTON-HEIGHT))))
          ; Arrow Click Logic
          (define click-left-arrow? (and (string=? tab "PHOTOS") 
                                        (> x (+ PANEL-X 45)) (< x (+ PANEL-X 75)) 
                                        (> y (+ PANEL-Y 225)) (< y (+ PANEL-Y 255))))
          (define click-right-arrow? (and (string=? tab "PHOTOS") 
                                         (> x (+ PANEL-X 275)) (< x (+ PANEL-X 305)) 
                                         (> y (+ PANEL-Y 225)) (< y (+ PANEL-Y 255))))
          ; get-clicked-planet-name : List<CelestialBody> -> String 
          ; Checks if the mouse click coordinates (x,y) are near a planet
          (define (get-clicked-planet-name bodies)
            (cond [(empty? bodies) locked-name] 
              [else (local [
                       (define body (first bodies))
                       (define target-body (find-body-by-name (sim-state-bodies current-state) locked-name))
                       (define target-loc (angle-to-location target-body))
                       (define body-loc (angle-to-location body))
                       (define draw-x (+ CENTER-X (* (- (location-x body-loc) 
                                                       (location-x target-loc)) zoom)))
                       (define draw-y (+ CENTER-Y (* (- (location-y body-loc) 
                                                       (location-y target-loc)) zoom)))
                       (define distance (sqrt (+ (sqr (- x draw-x)) (sqr (- y draw-y)))))]
                      (if (< distance 30) (celestial-body-name body) (get-clicked-planet-name (rest bodies))))]))]
    
    (cond
      [(mouse=? event "button-down")
       (cond
         [click-stats-btn? (make-sim-state bodies zoom x y locked-name idx "STATS" gal asteroids comets missions mission-mode selected-dep sim-time day-counter)]
         [click-info-btn?  (make-sim-state bodies zoom x y locked-name idx "INFO" gal asteroids comets missions mission-mode selected-dep sim-time day-counter)]
         [click-photo-btn? (make-sim-state bodies zoom x y locked-name idx "PHOTOS" gal asteroids comets missions mission-mode selected-dep sim-time day-counter)]
         
         [click-left-arrow? (make-sim-state bodies zoom x y locked-name idx tab 
                                           (if (= gal 1) 3 (- gal 1)) 
                                           asteroids comets missions mission-mode selected-dep sim-time day-counter)]
         [click-right-arrow? (make-sim-state bodies zoom x y locked-name idx tab 
                                            (if (= gal 3) 1 (+ gal 1)) 
                                            asteroids comets missions mission-mode selected-dep sim-time day-counter)]
         [click-in-panel? current-state]
         
         ; Mission Logic
         [(string=? mission-mode "selecting-departure")
          (local [(define clicked-planet (get-clicked-planet-name bodies))]
            (if (string=? clicked-planet "Sun")
                current-state  
                (make-sim-state bodies zoom x y clicked-planet idx tab 1 
                               asteroids comets missions 
                               "selecting-target" 
                               clicked-planet      
                               sim-time
                               day-counter)))] 
         
         [(string=? mission-mode "selecting-target")
          (local [(define clicked-planet (get-clicked-planet-name bodies))]
            (if (or (string=? clicked-planet "Sun") 
                    (string=? clicked-planet selected-dep))
                current-state  
                (launch-intercept-mission current-state selected-dep clicked-planet)))]
         ; Reset Gallery Index to 1 when switching planets
         [else (make-sim-state bodies zoom x y (get-clicked-planet-name bodies) idx tab 1 asteroids comets missions mission-mode selected-dep sim-time day-counter)])]
      
      [else (make-sim-state bodies zoom x y locked-name idx tab gal asteroids comets missions mission-mode selected-dep sim-time day-counter)])))

; main : SimState -> SimState
; run the solar-system animation starting from the given world
(define (main initial-state)
  (big-bang initial-state
    (on-tick next-world 1/100) 
    (to-draw draw-world)
    (on-key handle-key)
    (on-mouse handle-mouse)))

(main INITIAL-STATE)