breed [runners runner]
breed [spectators spectator]
breed [pacers pacer]
breed[raindrops raindrop]

runners-own [
  base-speed
  current-speed
  endurance
  motivation
  social-influence-susceptibility
  following-pacer?
  finish-time
  dropped-out?
  social-influence-susceptibility-quantile
  group-id
  laps-completed
  just-crossed-line?
  finished-race?
  total-distance
  total-distance-in-a-group
  group-runner
]

spectators-own [
  cheering-intensity
]

pacers-own [
  set-pace
  visibility
  group-size
]

globals [
  laps-required
  social-influence-radius
  track-size
  lawn-size
  lap-length-in-patches
]

to setup
  clear-all
  setup-environment
  setup-race-total-laps
  let total-solo-runners floor (number-of-runners * (percentage-of-solo-runners / 100))
  let total-grouped-runners number-of-runners - total-solo-runners

  if total-grouped-runners < 2 [
    user-message "Not enough runners to form a group. Increase total runners or decrease solo-runner-percent."
    stop
  ]

  setup-runners total-solo-runners total-grouped-runners
  average-speed-for-group-runners
  if weather = "wet"[
    setup-rain
  ]
  setup-spectators
  ;setup-pacers
  reset-ticks
end


to setup-environment
  ; Set all patches to represent the road
  ask patches [ set pcolor gray ]

  ; Define the central lawn area
  ask patches with [ abs(pycor) < 12 and abs(pxcor) < 12 ] [ set pcolor green ]
    ; Assuming the start/finish line is 5 patches long for demonstration.
  ; This line starts from the bottom left corner of the lawn and extends right.
  let start-finish-line-length 6
  ask patches with [pycor = -11 and pxcor >= -16 and pxcor < (-16 + start-finish-line-length)] [
    set pcolor ifelse-value (pxcor mod 2 = 0) [black] [white]
  ]
end



to setup-race-total-laps
  set laps-required race-distance / 1
  set lap-length-in-patches (33 * 4)
  ; Assuming total width of the environment (T) and width of the lawn (W)
  ;let total-width 32 ; This would be the total width from one end to the other of the environment.
  ;let lawn-width 24 ; This is the width of the lawn, so 12 patches from the center to each side.
  ;let track_width (total-width - lawn-width) / 2 ; This calculates the width of the track itself.
  ;let lap_length_in_patches track_width * 4 ; Since it's a square track, multiply by 4.
end

to setup-runners [total-solo-runners total-grouped-runners]
  ;let x-spacing (2 * (max-pxcor - 1)) / (number-of-runners + 1)
  ;let x-pos (min-pxcor + 1 + x-spacing)

  let start-line-y -11 ; Adjust based on your track setup
  let start-line-x-start -16
  let start-line-length 0.5  ; Length of your start line

  ; Calculate spacing if needed, to distribute runners along the start line.
  let spacing number-of-runners / start-line-length   ; This could be adjusted based on the number of runners and the length of the start line.

  let global-base-pace 6.28 ; average global base pace in minutes per km
  let global-space-sd 1     ;standard deviation for variability in pace

  create-runners number-of-runners [
    ;print(word "Number of runners:" number-of-runners)
    set shape "person"
    ;set color brown
    set size 1.5

    set base-speed random-normal global-base-pace global-space-sd
    set base-speed max(list 4.28 min(list base-speed 8.28))  ; Adjusted to cover 95% of the population (2 standard deviations)
    if weather = "wet" [
       set base-speed base-speed  * 1.15 ; decrease speed by 15%
    ]

    set-speed base-speed

    set endurance 1.0
    set motivation 1.0 ;min (list 1 max (list 0 random-normal 0.5 0.3))
    set social-influence-susceptibility min (list 1 max (list 0 random-normal 0.5 0.3))
      ; Assign colors based on social-influence-susceptibility
    let q1 0.25  ; 25th percentile
    let q2 0.75  ; 75th percentile

;    ifelse social-influence-susceptibility <= q1 [
;      set color violet  ; Runners within the 25th percentile are violet
;      set social-influence-susceptibility-quantile "first"
;    ] [
;      ifelse social-influence-susceptibility <= q2 [
;        set color brown  ; Runners between the 25th and 75th percentile are brown
;        set social-influence-susceptibility-quantile "average"
;      ] [
;        set color orange  ; Runners above the 75th percentile are orange
;        set social-influence-susceptibility-quantile "third"
;      ]
;    ]

    set finish-time 0
    ;set speed-consistency 0
    set dropped-out? false
    ;setxy x-pos (min-pycor + 1)
    ;move-to one-of patches with [ pcolor = gray and pxcor = -15 and pycor = -12 ]
    set laps-completed 0
    set total-distance 0
    set just-crossed-line? true  ; Prevent initial lap increase.

    ; Position runners on the start line.
    let assigned-x start-line-x-start + (who mod start-line-length) * spacing
    let assigned-y start-line-y
    setxy assigned-x assigned-y
    ;print(word "Runner starting x position: " pxcor " and y position: " pycor)
    set finished-race? false
    set heading 0
    set total-distance-in-a-group 0
    ;set x-pos (x-pos + x-spacing)
    place-runners-in-group  total-solo-runners

  ]


end

to place-runners-in-group [total-solo-runners]

   ifelse ( who ) < total-solo-runners [
      set group-id -1 ; indicate that these are solo runners
      set group-runner false
      set color white
      print (word "Runner: " who " has a base speed of " base-speed " and a current speed of: " current-speed " seconds per km and " (current-speed / 60) " m/km")
    ][
    set group-id 0
    set group-runner true
    set color pink
   ]
end

to average-speed-for-group-runners
    ; Calculate the average base speed for the group
    let group-runners runners with [group-id = 0]
    let average-base-speed mean [base-speed] of group-runners

    ; Set each group runner's speed to the group's average
    ask group-runners [
      set base-speed average-base-speed
      set-speed base-speed
      print (word "Runner: " who " has a base speed of " base-speed " and a current speed of: " current-speed " seconds per km and " (current-speed / 60) " m/km")
    ]
end


to setup-spectators
  create-spectators number-of-spectators [
    set shape "person"
    set color black
    set size 1
    set cheering-intensity random-float 1.0
    if weather = "wet" [
      set cheering-intensity cheering-intensity * 0.7 ; decrease cheering intensity by 30%
    ]
    move-to one-of patches with [ pcolor = green and abs(pxcor) < 14 and abs(pycor) < 14 ]
  ]
end

;to distribute-extra-runners [extra-runners]
;  let start-index total-solo-runners + (runners-per-group * number-of-groups)
;  ask n-of extra-runners runners with [who >= start-index] [
;    let new-group-id random number-of-groups
;    set group-id new-group-id
;    set color scale-color red new-group-id 0 number-of-groups - 1
;  ]
;end
;
;to check-groups [extra-runners]
;  if any? groups with [count runners with [group-id = [group-id] of myself] < 2] [
;    user-message "One or more groups have fewer than two runners. Adjusting runner distribution..."
;    distribute-extra-runners extra-runners ; Define this procedure to handle redistribution
;  ]
;end


;to setup-pacers
;  create-pacers number-of-pacers [
;    set shape "person"
;    set color yellow
;    set size 1
;    set set-pace random-float 1.0
;    set visibility random-float 1.0
;    set group-size 0
;    move-to one-of patches with [ pcolor = gray and pxcor = -15 and pycor = -15 ]
;    set heading 90
;  ]
;end

to set-speed [generated-speed]
   ; Ensure the fractional part of the speed does not exceed .59 by converting excess seconds to minutes
   let minutes floor generated-speed ; Whole number part of minutes
   let seconds round ((generated-speed - minutes) * 100) ; Convert fractional part to seconds

   ; Calculate additional minutes from excess seconds and adjust seconds to be within 0-59
   let extra-minutes floor (seconds / 60)
   let adjusted-seconds seconds mod 60

   ; Adjust minutes with any additional minutes from seconds
   set minutes minutes + extra-minutes

   ; Convert adjusted seconds back to a fraction of a minute and add to minutes
   set current-speed minutes + (adjusted-seconds / 100)
   set current-speed  current-speed * 60 ; convert speed from km/m to km/s
   ;set current-speed max(list (4.28 * 60) min(list current-speed (8.28 * 60)))  ; Adjusted to cover 95% of the population (2 standard deviations)
end


;to setup-rain
;  if weather = "wet" [
;    create-raindrops 50 [
;      set color blue
;      set shape "circle"
;      set size 0.4  ; Small size for raindrops
;      setxy random-xcor random-ycor
;      set heading 180  ; Point downwards initially
;    ]
;  ]
;end

to setup-rain
  if weather = "wet" [
    create-raindrops 500 [  ; Adjust number based on desired density
      set shape "circle"
      set color blue
      set size 0.5  ; Visual size of raindrops
      ; Place raindrops randomly across the x-axis and near the top of the world
      setxy random-xcor (max-pycor - 1)  ; Start near the top but within bounds
      set heading 180  ; Direct them to move downward
    ]
  ]
end

;to move-raindrops
;  ask raindrops [
;    rt random 360  ; Turn in a random direction
;    fd 0.3  ; Move forward by a small step
;    ; Wrap the raindrops around the world edges to maintain a constant number on screen
;    if pxcor > max-pxcor [ set xcor min-pxcor ]
;    if pxcor < min-pxcor [ set xcor max-pxcor ]
;    if pycor > max-pycor [ set ycor min-pycor ]
;    if pycor < min-pycor [ set ycor max-pycor ]
;  ]
;end

to move-raindrops
  ask raindrops [
    right random-float 10 - random-float 10  ; Slight random drift left or right
    fd 0.5  ; Move slowly to simulate gentle rain
    ; Check if raindrops go below the minimum y-coordinate and reset them
    if pycor < min-pycor [
      setxy random-xcor (max-pycor - 1)  ; Reset to the top just inside the world boundary
    ]
  ]
end


to go

  if all? runners [finished-race? or dropped-out?] [
    print "All runners have finished the race or dropped out."
    print (word "Simulation ends at time: " precision (ticks / 60) 2 " minutes.")
    analyze-group-running-results
    stop
  ]

  ask runners [
    if weather = "wet" [
      move-raindrops
    ]
    move-runners
    update-spectator-cheering
    update-runner-attributes
    form-running-groups
    ;leave-group
    ;check-if-dropped-out
    ;interact-with-nearby-spectators
    ;interact-with-nearby-pacers
    ;check-if-finished
  ]
;  ask pacers [
;    move-pacers
;    maintain-pace
;    gather-runners
;  ]
  tick
end

to move-runners
  ; Detect potential collision directly ahead and calculate available space for lateral movement.
  ;ask runners [
  if not finished-race?[


  let ahead-patch patch-ahead 1
  let collision-ahead? any? other runners with [patch-here = ahead-patch]

  if collision-ahead? [
    ; Determine the direction with more space for lateral movement.
    let left-space count (patches at-points [[-1 0]] with [pcolor != green and not any? other runners-here])
    let right-space count (patches at-points [[1 0]] with [pcolor != green and not any? other runners-here])

    ; Choose the direction with more available space to move.
    if left-space > right-space and left-space > 0 [
      move-laterally -1
    ]
    if right-space > 0 [
      move-laterally 1
    ]
  ]



    let patches-per-tick lap-length-in-patches / current-speed
    ;print(word "Runner: " who " is running at " patches-per-tick " patches per tick")
    fd patches-per-tick ;current-speed ;
    let distance-per-tick (1 / current-speed) ; Distance covered in 1 tick (minute), in kilometers
    ;print(word "Distance per tick " distance-per-tick)
    set total-distance total-distance + distance-per-tick
    ;print(word "Distance traveled " total-distance)
     ;if social-influence-susceptibility > 0.5 [
     calculate-distance-in-group distance-per-tick
    ;]

    update-laps-completed
    ; Adjust heading at track boundaries to stay within the track.
    adjust-heading-at-boundaries
  ]
  ;]
end

; Helper procedure to move runners laterally without direct xcor/ycor manipulation.
to move-laterally [dir]
  ; dir is -1 for left, 1 for right
  right dir * 90
  fd 1
  left dir * 90
end

; Helper procedure to adjust heading at track boundaries.
to adjust-heading-at-boundaries
  if (pxcor >= 15 and heading = 90) or (pxcor <= -15 and heading = 270) [
    set heading (heading + 90) mod 360
  ]
  if (pycor >= 15 and heading = 0) or (pycor <= -15 and heading = 180) [
    set heading (heading + 90) mod 360
  ]
end




to move-pacers
  ; Move the pacer forward in the direction it's facing
  fd set-pace
  ; Check if the pacer needs to turn based on its current position and heading
  if (pxcor = 15 and heading = 90) or (pxcor = -15 and heading = 270) [
    set heading (heading + 90) mod 360
  ]
  if (pycor = 15 and heading = 0) or (pycor = -15 and heading = 180) [
    set heading (heading + 90) mod 360
  ]
end

to update-spectator-cheering
  ask spectators [
    ; Increase cheering intensity as the race progresses and reset periodically
    ifelse ticks mod 60 < 30 [  ; Assuming a cyclic pattern every minute
      set cheering-intensity min(list 1.0 (cheering-intensity + 0.01))
    ][
      set cheering-intensity max(list 0.5 (cheering-intensity - 0.01))
    ]
  ]
end


to form-running-groups

 ; Check if the runner's social-influence-susceptibility is high enough to form a group
  ;print(word "Social influence" social-influence-susceptibility)
  if not finished-race? and group-runner [
  ifelse social-influence-susceptibility > 0.5 [
      ; Check for nearby runners based on distance
      let nearby-runners other runners in-radius 2 with [group-runner = true]
      ifelse any? nearby-runners [
      ; Find the runner with the closest speed
      let closest-runner min-one-of nearby-runners [abs (current-speed - [current-speed] of myself)]
      let closest-speed [current-speed] of closest-runner
      let speed-diff abs (current-speed - closest-speed)

      ; If the speed difference is within the tolerance range
      if speed-diff <= 0.1 [
           ;print("Forming group")
        ; Form a group and change color to pink
        set color pink
        set group-id 0
        ;set group-id [group-id] of closest-runner ; group id of closet runner is currently -1
        ask closest-runner [
          set color pink
          set group-id 0
        ]
      ]

    ][
    ; If the runner is pink and there are no other pink runners within a certain radius
;    if color = pink and not any? other runners in-radius 3 with [color = pink] [
;        ; instead of immediately reverting color, mark this runner for reversion
;        set group-id -2  ; Using -2 as an example mark for reversion
;        ;revert-color-based-on-quantile
;      ]
        ;print(word "Runner " who " dropped out of group")
        set group-id -2

    ]

    ; Now, revert color for all marked runners collectively
    ask runners with [group-id = -2] [
    ; Revert color based on social-influence-susceptibility-quantile
    revert-color-based-on-quantile
    ; Reset group-id back to -1 indicating they are no longer in a group
    set group-id -1
  ]

  ][

    ; If the runner is pink and there are no other pink runners within a certain radius
    if color = pink and not any? other runners in-radius 4 with [color = pink] [
        ; instead of immediately reverting color, mark this runner for reversion
        set group-id -2  ; Using -2 as an example mark for reversion
        ;revert-color-based-on-quantile
      ]

  ]
  ]

end

to leave-group
  if not finished-race? and group-runner = true and group-id != 0 [

   print(word "Runner " who " dropped out of group, social influence" social-influence-susceptibility)
;      ifelse any? nearby-runners [
;      ; Find the runner with the closest speed
;      let closest-runner min-one-of nearby-runners [abs (current-speed - [current-speed] of myself)]
;      let closest-speed [current-speed] of closest-runner
;      let speed-diff abs (current-speed - closest-speed)
;
;      ; If the speed difference is within the tolerance range
;      if speed-diff <= 0.1 [
;           ;print("Forming group")
;        ; Form a group and change color to pink
;        set color pink
;        set group-id 1
;        ;set group-id [group-id] of closest-runner ; group id of closet runner is currently -1
;        ask closest-runner [
;          set color pink
;          set group-id 1
;        ]
;      ]
;    ]
  ]
end

to revert-color-based-on-quantile
  ; Change color back to the original color based on social-influence-susceptibility quantile
    let q1 0.25  ; 25th percentile
    let q2 0.75  ; 75th percentile
    ifelse social-influence-susceptibility <= q1 [
      set color violet  ; Runners within the 25th percentile are violet
    ] [
      ifelse social-influence-susceptibility <= q2 [
        set color brown  ; Runners between the 25th and 75th percentile are brown
      ] [
        set color orange  ; Runners above the 75th percentile are orange
      ]
    ]

end

to calculate-distance-in-group[distance-covered]
  if group-id = 0 [
     set total-distance-in-a-group   total-distance-in-a-group + distance-covered
  ]

end
to update-runner-attributes
  ask runners [
    if not dropped-out? [
      let motivation-decrement 0.00001
      let social-suspectible-motivation-decrement 0.00002

      if weather = "wet"[
       set motivation-decrement 0.0001
       set social-suspectible-motivation-decrement 0.0002
      ]

      ; Adjust motivation
      ifelse group-id != 0 [ ; Not in a group
        ifelse group-runner = true [

          ifelse social-influence-susceptibility > 0.5 [
            ;print(word "Runner(social) " who " current motivation " motivation " group id " group-id)
            let nearby-spectators spectators in-radius 4
            ifelse any? nearby-spectators[
               let avg-cheering-intensity mean [cheering-intensity] of nearby-spectators
               print(word "Found nearby fans adding to motivation " (avg-cheering-intensity * 0.10))
               set motivation motivation - social-suspectible-motivation-decrement + (avg-cheering-intensity * 0.10)
            ][
               set motivation motivation - social-suspectible-motivation-decrement
            ]
            ;print(word "Runner(social) " who " motivation decrease to " motivation " group id " group-id)
          ][
            set motivation motivation - motivation-decrement; Increased motivation decrease for highly susceptible runners
            ;print(word "Runner " who " motivation decrease to " motivation " group id " group-id)
          ]
        ]  [
          set motivation motivation - motivation-decrement ; Standard motivation decrease
        ]
      ]  [ ; In a group
        set motivation motivation - motivation-decrement ; Standard motivation decrease
        let group-mates runners with [group-id = [group-id] of myself]
        let group-motivation mean [motivation] of group-mates
        ;print(word "Group motivation" group-motivation)
        set motivation (motivation + group-motivation) / 2 ; Adjust motivation towards group average
      ]

      ; Ensure motivation stays within bounds
      ;set motivation max list 0 min list motivation 1

      ; Adjust endurance based on motivation and possibly speed

      ;print(word "Runner " who "endurance is " endurance)
      let speed-to-endurance-ratio 1
      if race-distance >= 5 and race-distance <= 10 [
       ; Middle distance run, 5km - 10km
        ;set speed-to-endurance-ratio 3 / 2
        let endurance_decrease_rate 0.000001 + (0.5 - motivation) * 0.000001
        set endurance endurance - endurance_decrease_rate
      ]
      if race-distance = 21 [
        ; Long distance run, 21km
        set speed-to-endurance-ratio 1
        let endurance_decrease_rate 0.000001 + (0.5 - motivation) * 0.000001
        set endurance endurance - endurance_decrease_rate

      ]
       if race-distance >= 42 [
       ; Full marathon, 42km
        ;set speed-to-endurance-ratio  2 / 3
        let endurance_decrease_rate 0.0000001 + (0.5 - motivation) * 0.0000001
        set endurance endurance - endurance_decrease_rate
      ]
      ; Adjust speed
      ifelse endurance <= 0 [
       drop-out
    ] [
        set-speed ( base-speed / ( endurance * speed-to-endurance-ratio) )

;        if group-id = 0 [ ; Not in a group
;          print(word "Runner " who " base speed " base-speed "current speed " current-speed)
;                    print(word "Runner " who " endurance " endurance )
;        ]

        ;if ticks mod 60 = 0 [ ; Log every 60 ticks as an example
         ; print (word "Runner " who " current speed: " (current-speed / 60) " m/km, total distance: " total-distance " km, time: " (ticks / 60) " minutes")
        ;]
      ]
  ]
  ]
end

to update-attributes-for-dry-weather

end

to drop-out

  ; Mark the runner as dropped out
  set dropped-out? true
  set finish-time ticks / 60  ; Record the time in minutes at the moment of dropping out
  print (word "Runner " who " has dropped out at time: " precision finish-time 2 " minutes \n and speed of " precision current-speed 2 " m/km and endurance of " endurance " \n and motivation " motivation)
  set color red ; Indicative of dropping out
  ; Move to a designated area or disappear from the race
  move-to one-of patches with [pcolor = green]
  die;
end




to update-laps-completed
  ask runners [
    let laps-completed-before laps-completed
    ;print(word "Laps completed before " laps-completed-before)
    set laps-completed floor ((total-distance * lap-length-in-patches)  / lap-length-in-patches)
    ;print(word "Laps completed " laps-completed)
    if laps-completed > laps-completed-before [
      ;print (word "Runner " who " has completed lap " laps-completed " at tick: " ticks)
    ]
    if laps-completed >= laps-required and not finished-race? [
      complete-race
    ]
  ]
end


to complete-race  ; A new procedure for handling race completion.
  ; Assuming 1 tick = 1 minute for simplicity, adjust as necessary.
  set finished-race? true
  set finish-time ticks / 60
  move-to one-of patches with [pcolor = green]  ; Move completed runners off the track.
  if total-distance-in-a-group > race-distance * 0.5 [
    set group-id 0
  ]
  print (word "Runner " who " completed the race in " precision finish-time 2 " minutes and a speed of " precision (current-speed / 60 ) 2 " m/km. Distance in a group " precision total-distance-in-a-group 2 " km")
end

to analyze-group-running-results
  if all? runners [finished-race?] [
    let group-runners runners with [( group-id = 0 and finish-time > 0 )]
    let solo-runners runners with [group-id = -1 and finish-time > 0]
    print(word "Total group runners " count group-runners)
    print(word "Total solo runners " count solo-runners)
    if count runners > 0 [
    ; Use count to check if the agentset is empty
    let avg-group-time ( ifelse-value (count group-runners > 0) [mean [finish-time] of group-runners] [0] )
    let avg-solo-time ( ifelse-value (count solo-runners > 0) [mean [finish-time] of solo-runners] [0] )

    let avg-group-speed ( ifelse-value (count group-runners > 0) [mean [current-speed] of group-runners] [0] ) / 60
    let avg-solo-speed ( ifelse-value (count solo-runners > 0) [mean [current-speed] of solo-runners] [0] ) / 60



    let avg-distance mean [total-distance] of runners
    let avg-group-distance ifelse-value (count group-runners > 0) [mean [total-distance] of group-runners] [0]
    let avg-solo-distance ifelse-value (count solo-runners > 0) [mean [total-distance] of solo-runners] [0]

    print (word "Race distance: " precision race-distance 2 " km")
    print (word "Average distance: " precision avg-distance 2 " km")

    ;print (word "Average group finish time: " precision  avg-group-time 2" minutes")
    ;print (word "Average solo finish time: " precision  avg-solo-time 2" minutes")

    print (word "Average group finish time: " precision  ( avg-group-time )  2" minutes")
    print (word "Average solo finish time: " precision  ( avg-solo-time ) 2" minutes")

    print (word "Average group speed: " precision  avg-group-speed 2 " min/km")
    print (word "Average solo speed: " precision avg-solo-speed 2 " min/km")
    ]
  ]
end

; Assuming finish-time is in minutes
to-report formatted-time [time-minutes]
  let minutes floor time-minutes
  let seconds round (time-minutes - minutes) * 60
  report (word minutes "m " seconds "s")
end


to-report avg-group-runner-speed
  let group-runners runners with [( group-id = 0 )]
  let avg-group-speed ( ifelse-value (count group-runners > 0) [mean [current-speed] of group-runners] [0] ) / 60
  report precision avg-group-speed 2
end


to-report avg-solo-runner-speed
  let solo-runners runners with [group-id = -1]
  let avg-solo-speed ( ifelse-value (count solo-runners > 0) [mean [current-speed] of solo-runners] [0] ) / 60
  report precision avg-solo-speed 2
end

to-report running-in-group
  let group-runners runners with [( group-id = 0 ) ]
  report count group-runners
end

to-report running-solo
  let solo-runners runners with [group-id = -1 ]
  report count solo-runners
end

to-report group-social-suspectible-runners-avg-speed
  let social-suspectible-runners runners with [(group-id = 0 and social-influence-susceptibility > 0.5)]
  let avg-group-speed ( ifelse-value (count social-suspectible-runners > 0) [mean [current-speed] of social-suspectible-runners] [0] ) / 60
  report avg-group-speed
end

to-report solo-social-suspectible-runners-avg-speed
  let social-suspectible-runners runners with [(group-id = -1 and social-influence-susceptibility > 0.5)]
  let avg-solo-speed ( ifelse-value (count social-suspectible-runners > 0) [mean [current-speed] of social-suspectible-runners] [0] ) / 60
  report avg-solo-speed
end


to-report group-non-social-suspectible-runners-avg-speed
  let non-social-suspectible-runners runners with [(group-id = 0 and social-influence-susceptibility <= 0.5 )]
  let avg-group-speed ( ifelse-value (count non-social-suspectible-runners > 0) [mean [current-speed] of non-social-suspectible-runners] [0] ) / 60
  report avg-group-speed
end

to-report solo-non-social-suspectible-runners-avg-speed
  let non-social-suspectible-runners runners with [(group-id = -1 and social-influence-susceptibility <= 0.5 )]
  let solo-group-speed ( ifelse-value (count non-social-suspectible-runners > 0) [mean [current-speed] of non-social-suspectible-runners] [0] ) / 60
  report solo-group-speed
end

;to-report avg-solo-runners-speed
;  let solo-runners runners with [not any? other runners in-radius social-influence-radius]
;  ifelse count solo-runners > 0 [
;    report mean [speed] of solo-runners
;  ][
;    report 0
;  ]
;end



;to interact-with-nearby-spectators
;  ; Check for nearby spectators and adjust motivation based on their cheering
;  ; You can customize this based on your specific spectator influence rules
;  ; Example:
;  let nearby-spectators spectators in-radius 1
;  if any? nearby-spectators [
;    let average-cheering-intensity mean [cheering-intensity] of nearby-spectators
;    set motivation motivation * (1 - social-influence-susceptibility) + average-cheering-intensity * social-influence-susceptibility
;  ]
;end

to check-if-finished
  ; Check if the runner has reached the finish line
  if pycor = max-pycor [
    set color green
    ;die
    stop
  ]
end

to interact-with-nearby-pacers
  ; Check for nearby pacers and decide whether to follow them
  ; You can customize this based on your specific pacer influence rules
  ; Example:
  let nearby-pacers pacers in-radius social-influence-radius
  if any? nearby-pacers and not following-pacer? [
    let most-visible-pacer max-one-of nearby-pacers [visibility]
    if random-float 1.0 < [visibility] of most-visible-pacer [
      set following-pacer? true
      set current-speed [set-pace] of most-visible-pacer
      ask most-visible-pacer [set group-size group-size + 1]
    ]
  ]
end

to maintain-pace
  ; Pacers maintain their set pace and slightly adjust to support runner needs
  ; You can customize this based on your specific pacer behavior rules
  ; Example:
  fd set-pace
  if group-size > 0 [
    let average-runner-speed mean [current-speed] of runners with [following-pacer? and distance myself < social-influence-radius]
    set set-pace set-pace * 0.9 + average-runner-speed * 0.1
  ]
end

to gather-runners
  ; Pacers encourage nearby runners to join their group
  ; You can customize this based on your specific pacer-runner interaction rules
  ; Example:
  let nearby-runners runners in-radius social-influence-radius with [not following-pacer?]
  if any? nearby-runners [
    ask nearby-runners [
      if random-float 1.0 < [visibility] of myself [
        set following-pacer? true
        set current-speed [set-pace] of myself
        ask myself [set group-size group-size + 1]
      ]
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
306
32
920
647
-1
-1
18.364
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
25
78
91
111
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
110
77
173
110
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
16
196
194
229
number-of-runners
number-of-runners
1
20
20.0
1
1
NIL
HORIZONTAL

SLIDER
15
304
209
337
number-of-spectators
number-of-spectators
0
100
0.0
1
1
NIL
HORIZONTAL

CHOOSER
15
246
153
291
race-distance
race-distance
5 10 21 42.5
1

SLIDER
13
150
217
183
percentage-of-solo-runners
percentage-of-solo-runners
0
100
50.0
1
1
NIL
HORIZONTAL

PLOT
949
200
1149
350
Group vs Solo Runners
NIL
NIL
0.0
10.0
0.0
20.0
true
false
"" ""
PENS
"group runners" 1.0 0 -955883 true "" "plot count runners with [group-id = 0 ]"
"solo runners" 1.0 0 -6459832 true "" "plot count runners with [group-id != 0 ]"

MONITOR
949
139
1097
184
Group Running Speed
avg-group-runner-speed
17
1
11

MONITOR
950
88
1073
133
Runners in Group
running-in-group
17
1
11

MONITOR
1107
87
1202
132
Solo Runners
running-solo
17
1
11

MONITOR
1106
139
1288
184
Average Solo Runner Speed
avg-solo-runner-speed
17
1
11

CHOOSER
159
246
299
291
weather
weather
"dry" "wet"
0

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Dry weather group runners vs solo runners and no spectators" repetitions="2" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="percentage-of-solo-runners">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="race-distance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-runners">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-spectators">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weather">
      <value value="&quot;dry&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dry weather group runners vs solo runners and no spectators (10km)" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>running-in-group</metric>
    <metric>avg-group-runner-speed</metric>
    <metric>group-social-suspectible-runners-avg-speed</metric>
    <metric>group-non-social-suspectible-runners-avg-speed</metric>
    <metric>running-solo</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>solo-social-suspectible-runners-avg-speed</metric>
    <metric>solo-non-social-suspectible-runners-avg-speed</metric>
    <enumeratedValueSet variable="percentage-of-solo-runners">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="race-distance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-runners">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-spectators">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weather">
      <value value="&quot;dry&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
