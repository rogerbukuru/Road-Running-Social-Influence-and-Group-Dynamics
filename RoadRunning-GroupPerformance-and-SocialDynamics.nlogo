breed [runners runner]
breed [spectators spectator]
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

patches-own[
  is-lawn
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
  let solo-total-runners floor (number-of-runners * (percentage-of-solo-runners / 100))
  let total-grouped-runners number-of-runners - solo-total-runners

  if total-grouped-runners < 2 [
    user-message "Not enough runners to form a group. Increase total runners or decrease solo-runner-percent."
    stop
  ]

  setup-runners solo-total-runners total-grouped-runners
  average-speed-for-group-runners
  ifelse weather = "wet"[
    setup-rain
  ][
    let sun-x max-pxcor - 2
    let sun-y max-pycor - 2
    ask patches with [pxcor > sun-x and pycor > sun-y] [
      set pcolor yellow
    ]
    ask patch (sun-x + 1) (sun-y + 1) [ set pcolor yellow - 0.5 ]
    ask patch (sun-x + 1) (sun-y - 1) [ set pcolor yellow - 0.5 ]
    ask patch (sun-x - 1) (sun-y + 1) [ set pcolor yellow - 0.5 ]
    ask patch (sun-x - 1) (sun-y - 1) [ set pcolor yellow - 0.5 ]

  ]
  setup-spectators
  reset-ticks
end


to setup-environment
  ; All patches to represent the road
  ask patches [
    set pcolor gray
    set is-lawn false
  ]

  ; Central lawn area
  ask patches with [ abs(pycor) < 12 and abs(pxcor) < 12 ] [
   set pcolor scale-color green ((random 500) + 5000) 0 9000
   set is-lawn true
  ]
  let start-finish-line-length 6
  ask patches with [pycor = -11 and pxcor >= -16 and pxcor < (-16 + start-finish-line-length)] [
    set pcolor ifelse-value (pxcor mod 2 = 0) [black] [white]
  ]
end



to setup-race-total-laps
  set laps-required race-distance / 1
  set lap-length-in-patches (33 * 4)
end

to setup-runners [solo-total-runners total-grouped-runners]

  let start-line-y -11
  let start-line-x-start -16
  let start-line-length 0.5

  let spacing number-of-runners / start-line-length
  let global-base-pace 6.28 ; average global base pace in minutes per km
  let global-space-sd 1     ;standard deviation for variability in pace

  create-runners number-of-runners [
    set shape "person"
    set size 1.5

    set base-speed random-normal global-base-pace global-space-sd
    set base-speed max(list 4.28 min(list base-speed 8.28))  ; Adjusted to cover 95% of the population (2 standard deviations)
    if weather = "wet" [
       set base-speed base-speed  * 1.15 ; decrease speed by 15%
    ]
    set-speed base-speed
    set endurance 1.0
    set motivation 1.0
    set social-influence-susceptibility min (list 1 max (list 0 random-normal 0.5 0.3))
    set finish-time 0
    set dropped-out? false
    set laps-completed 0
    set total-distance 0
    set just-crossed-line? true  ; To prevent initial lap increase.
    ; Position runners on the start line.
    let assigned-x start-line-x-start + (who mod start-line-length) * spacing
    let assigned-y start-line-y
    setxy assigned-x assigned-y
    set finished-race? false
    set heading 0
    set total-distance-in-a-group 0
    place-runners-in-group  solo-total-runners

  ]


end

to place-runners-in-group [solo-total-runners]

   ifelse ( who ) < solo-total-runners [
      set group-id -1 ; indicate that these are solo runners
      set group-runner false
      set color white
      ;print (word "Runner: " who " has a base speed of " base-speed " and a current speed of: " current-speed " seconds per km and " (current-speed / 60) " m/km")
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
      ;print (word "Runner: " who " has a base speed of " base-speed " and a current speed of: " current-speed " seconds per km and " (current-speed / 60) " m/km")
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
    move-to one-of patches with [ is-lawn = true ]
  ]
end


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

end


to setup-rain
  if weather = "wet" [
    create-raindrops 500 [
      set shape "circle"
      set color blue
      set size 0.5
      ; Place raindrops randomly across the x-axis and near the top of the world
      setxy random-xcor (max-pycor - 1)  ; Start near the top but within bounds
      set heading 180  ; Direct them to move downward
    ]
  ]
end


to move-raindrops
  ask raindrops [
    right random-float 10 - random-float 10  ; Slight random drift left or right
    fd 0.5  ; Move slowly to simulate gentle rain
    if pycor < min-pycor [
      setxy random-xcor (max-pycor - 1)
    ]
  ]
end


to go

  if all? runners [finished-race? or dropped-out?] [
    ;print "All runners have finished the race or dropped out."
    ;print (word "Simulation ends at time: " precision (ticks / 60) 2 " minutes.")
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
  ]
  tick
end

to move-runners
  ; Detect potential collision directly ahead and calculate available space for lateral movement.

  if not finished-race?[
  let ahead-patch patch-ahead 1
  let collision-ahead? any? other runners with [patch-here = ahead-patch]

  if collision-ahead? [
    ; Determine the direction with more space for lateral movement.
    let left-space count (patches at-points [[-1 0]] with [is-lawn = false and not any? other runners-here])
    let right-space count (patches at-points [[1 0]] with [is-lawn = false and not any? other runners-here])

    ; Choose the direction with more available space to move.
    if left-space > right-space and left-space > 0 [
      move-laterally -1
    ]
    if right-space > 0 [
      move-laterally 1
    ]
  ]



    let patches-per-tick lap-length-in-patches / current-speed

    fd patches-per-tick ;current-speed ;
    let distance-per-tick (1 / current-speed) ; Distance covered in 1 tick (minute), in kilometers
    set total-distance total-distance + distance-per-tick
    calculate-distance-in-group distance-per-tick

    update-laps-completed
    adjust-heading-at-boundaries
  ]
  ;]
end

; Helper procedure to move runners laterally without direct xcor/ycor manipulation.
to move-laterally [dir]
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



to update-spectator-cheering
  ask spectators [
    ; Increase cheering intensity as the race progresses and reset periodically
    ifelse ticks mod 60 < 30 [  ; We assume a cyclic pattern every minute
      set cheering-intensity min(list 1.0 (cheering-intensity + 0.01))
    ][
      set cheering-intensity max(list 0.5 (cheering-intensity - 0.01))
    ]
  ]
end


to form-running-groups

  if not finished-race? and group-runner [
  ; Check if the runner's social-influence-susceptibility is high enough to form a group
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
        ; Form a group and change color to pink
        set color pink
        set group-id 0
        ask closest-runner [
          set color pink
          set group-id 0
        ]
      ]

    ][
        set group-id -2

    ]

    ask runners with [group-id = -2] [
    ; Revert color based on social-influence-susceptibility-quantile
    revert-color-based-on-quantile
    ; Reset group-id back to -1 indicating runner is no longer in a group
    set group-id -1
  ]

  ][
    if color = pink and not any? other runners in-radius 4 with [color = pink] [
        set group-id -2
      ]

  ]
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
       set motivation-decrement 0.00005
       set social-suspectible-motivation-decrement 0.00004
      ]

      ; Adjust motivation
      ifelse group-id != 0 [ ; Not in a group
          ifelse social-influence-susceptibility > 0.5 [
            set motivation motivation - social-suspectible-motivation-decrement
            let nearby-spectators spectators in-radius 4
            if any? nearby-spectators[
               let avg-cheering-intensity mean [cheering-intensity] of nearby-spectators
               set motivation motivation + (avg-cheering-intensity * 0.0001)
            ]
          ][
            set motivation motivation - motivation-decrement
            let nearby-spectators spectators in-radius 4
            if any? nearby-spectators[
               let avg-cheering-intensity mean [cheering-intensity] of nearby-spectators
               set motivation motivation + (avg-cheering-intensity * 0.00005)
            ]
          ]
      ]  [ ; In a group
        set motivation motivation - motivation-decrement ; Standard motivation decrease
        let nearby-spectators spectators in-radius 4
        if any? nearby-spectators[
           let avg-cheering-intensity mean [cheering-intensity] of nearby-spectators
           set motivation motivation + (avg-cheering-intensity * 0.00005)
        ]
        let group-mates runners with [group-id = [group-id] of myself]
        let group-motivation mean [motivation] of group-mates
        set motivation (motivation + group-motivation) / 2 ; Adjust motivation towards group average
      ]

      let speed-to-endurance-ratio 1
      if race-distance >= 5 and race-distance <= 10 [
       ; Middle distance run, 5km - 10km
        let endurance_decrease_rate 0.000001 + (0.5 - motivation) * 0.000001
        set endurance endurance - endurance_decrease_rate
      ]
      if race-distance = 21 [
        ; Long distance run, 21km
        let endurance_decrease_rate 0.0000001 + (0.5 - motivation) * 0.0000001
        set endurance endurance - endurance_decrease_rate

      ]
       if race-distance >= 42 [
       ; Full marathon, 42km
        let endurance_decrease_rate 0.00000001 + (0.5 - motivation) * 0.00000001
        set endurance endurance - endurance_decrease_rate
      ]
      ; Adjust speed
      ifelse endurance <= 0 [
       drop-out
    ] [
        set-speed ( base-speed / ( endurance * speed-to-endurance-ratio) )
      ]
  ]
  ]
end



to drop-out

  ; Mark the runner as dropped out
  set dropped-out? true
  set finish-time ticks / 60  ; Record the time in minutes at the moment of dropping out
  ;print (word "Runner " who " has dropped out at time: " precision finish-time 2 " minutes \n and speed of " precision current-speed 2 " m/km and endurance of " endurance " \n and motivation " motivation)
  set color red ; Indicative of dropping out
  ; Move to a designated area or disappear from the race
  move-to one-of patches with [is-lawn = true]
  die;
end



to update-laps-completed
  ask runners [
    let laps-completed-before laps-completed
    set laps-completed floor ((total-distance * lap-length-in-patches)  / lap-length-in-patches)
    if laps-completed >= laps-required and not finished-race? [
      complete-race
    ]
  ]
end


to complete-race
  set finished-race? true
  set finish-time ticks / 60
  move-to one-of patches with [is-lawn = true] ; Move completed runners off the track.
  if total-distance-in-a-group > race-distance * 0.5 [
    set group-id 0
  ]
  ;print (word "Runner " who " completed the race in " precision finish-time 2 " minutes and a speed of " precision (current-speed / 60 ) 2 " m/km. Distance in a group " precision total-distance-in-a-group 2 " km")
end

to analyze-group-running-results
  if all? runners [finished-race?] [
    let group-runners runners with [( group-id = 0 and finish-time > 0 )]
    let solo-runners runners with [group-id = -1 and finish-time > 0]
    ;print(word "Total group runners " count group-runners)
    ;print(word "Total solo runners " count solo-runners)
    if count runners > 0 [
    let avg-group-time ( ifelse-value (count group-runners > 0) [mean [finish-time] of group-runners] [0] )
    let avg-solo-time ( ifelse-value (count solo-runners > 0) [mean [finish-time] of solo-runners] [0] )

    let avg-group-speed ( ifelse-value (count group-runners > 0) [mean [current-speed] of group-runners] [0] ) / 60
    let avg-solo-speed ( ifelse-value (count solo-runners > 0) [mean [current-speed] of solo-runners] [0] ) / 60



    let avg-distance mean [total-distance] of runners
    let avg-group-distance ifelse-value (count group-runners > 0) [mean [total-distance] of group-runners] [0]
    let avg-solo-distance ifelse-value (count solo-runners > 0) [mean [total-distance] of solo-runners] [0]

;    print (word "Race distance: " precision race-distance 2 " km")
;    print (word "Average distance: " precision avg-distance 2 " km")
;
;    ;print (word "Average group finish time: " precision  avg-group-time 2" minutes")
;    ;print (word "Average solo finish time: " precision  avg-solo-time 2" minutes")
;
;    print (word "Average group finish time: " precision  ( avg-group-time )  2" minutes")
;    print (word "Average solo finish time: " precision  ( avg-solo-time ) 2" minutes")
;
;    print (word "Average group speed: " precision  avg-group-speed 2 " min/km")
;    print (word "Average solo speed: " precision avg-solo-speed 2 " min/km")
    ]
  ]
end



;;;;;;;; Group Runner Metrics

to-report total-runners-in-group
  let group-runners runners with [( group-id = 0 ) ]
  report count group-runners
end

to-report avg-group-runners-finish-time
  let group-runners runners with [( group-id = 0 )]
  let avg-finish-time ( ifelse-value (count group-runners > 0) [mean [finish-time] of group-runners] [0] )
  report precision avg-finish-time 2
end

to-report avg-group-runners-speed
  let group-runners runners with [( group-id = 0 )]
  let avg-group-speed ( ifelse-value (count group-runners > 0) [mean [current-speed] of group-runners] [0] ) / 60
  report word precision avg-group-speed 2 "m/km"
end


to-report total-socially-suspectible-runners-in-group
  let social-suspectible-runners runners with [(group-id = 0 and social-influence-susceptibility > 0.5)]
  report count social-suspectible-runners
end

to-report socially-suspectible-group-runners-avg-finish-time
  let social-suspectible-runners runners with [(group-id = 0 and social-influence-susceptibility > 0.5)]
  let avg-finish-time ( ifelse-value (count social-suspectible-runners > 0) [mean [finish-time] of social-suspectible-runners] [0] )
  report precision avg-finish-time 2
end

to-report socially-suspectible-group-runners-avg-speed
  let social-suspectible-runners runners with [(group-id = 0 and social-influence-susceptibility > 0.5)]
  let avg-group-speed ( ifelse-value (count social-suspectible-runners > 0) [mean [current-speed] of social-suspectible-runners] [0] ) / 60
  report avg-group-speed
end


to-report non-socially-suspectible-group-runners-avg-finish-time
  let non-social-suspectible-runners runners with [(group-id = 0 and social-influence-susceptibility <= 0.5 )]
  let avg-finish-time ( ifelse-value (count non-social-suspectible-runners > 0) [mean [finish-time] of non-social-suspectible-runners] [0] )
  report precision avg-finish-time 2
end

to-report non-socially-suspectible-group-runners-avg-speed
  let non-social-suspectible-runners runners with [(group-id = 0 and social-influence-susceptibility <= 0.5 )]
  let avg-group-speed ( ifelse-value (count non-social-suspectible-runners > 0) [mean [current-speed] of non-social-suspectible-runners] [0] ) / 60
  report avg-group-speed
end




;;;;;;;;; Solo Runner Metrics ;;;;;;;;;;;;;

to-report total-solo-runners
  let solo-runners runners with [group-id = -1 ]
  report count solo-runners
end

to-report avg-solo-runner-finish-time
  let solo-runners runners with [( group-id = -1 )]
  let avg-finish-time ( ifelse-value (count solo-runners > 0) [mean [finish-time] of solo-runners] [0] )
  report precision avg-finish-time 2
end

to-report avg-solo-runner-speed
  let solo-runners runners with [group-id = -1]
  let avg-solo-speed ( ifelse-value (count solo-runners > 0) [mean [current-speed] of solo-runners] [0] ) / 60
  report word precision avg-solo-speed 2 "m/km"
end


to-report total-solo-socially-suspectible-runners
  let social-suspectible-runners runners with [(group-id = -1 and social-influence-susceptibility > 0.5)]
  report count social-suspectible-runners
end

to-report socially-suspectible-solo-runners-avg-finish-time
  let social-suspectible-runners runners with [(group-id = -1 and social-influence-susceptibility > 0.5)]
  let avg-finish-time ( ifelse-value (count social-suspectible-runners > 0) [mean [finish-time] of social-suspectible-runners] [0] )
  report precision avg-finish-time 2
end


to-report socially-suspectible-solo-runners-avg-speed
  let social-suspectible-runners runners with [(group-id = -1 and social-influence-susceptibility > 0.5)]
  let avg-solo-speed ( ifelse-value (count social-suspectible-runners > 0) [mean [current-speed] of social-suspectible-runners] [0] ) / 60
  report avg-solo-speed
end


to-report non-socially-suspectible-solo-runners-avg-finish-time
  let non-social-suspectible-runners runners with [(group-id = -1 and social-influence-susceptibility <= 0.5 )]
  let avg-finish-time ( ifelse-value (count non-social-suspectible-runners > 0) [mean [finish-time] of non-social-suspectible-runners] [0] )
  report precision avg-finish-time 2
end

to-report non-social-suspectible-solo-runners-avg-speed
  let non-social-suspectible-runners runners with [(group-id = -1 and social-influence-susceptibility <= 0.5 )]
  let solo-group-speed ( ifelse-value (count non-social-suspectible-runners > 0) [mean [current-speed] of non-social-suspectible-runners] [0] ) / 60
  report solo-group-speed
end

to-report average-distance-covered
  let average-distance-completed mean [total-distance] of runners
  report average-distance-completed
end

to-report average-laps-completed
  let average-lap-completed mean [laps-completed] of runners
  report (word average-lap-completed "/" laps-required)
end


to-report elapsed-time
  let total-seconds ticks
  let hours floor (total-seconds / 3600)
  let minutes floor ((total-seconds mod 3600) / 60)
  let seconds total-seconds mod 60

  let formatted-hours (ifelse-value (hours < 10) [word "0" hours] [hours])
  let formatted-minutes (ifelse-value (minutes < 10) [word "0" minutes] [minutes])
  let formatted-seconds (ifelse-value (seconds < 10) [word "0" seconds] [seconds])

  report (word formatted-hours ":" formatted-minutes ":" formatted-seconds)
end


to-report group-runners-formatted-time

  let group-runners runners with [( group-id = 0 )]
  let avg-finish-time ( ifelse-value (count group-runners > 0) [mean [finish-time] of group-runners] [0] )
  ifelse avg-finish-time > 0 [

  let total-seconds avg-finish-time * 60
  let hours floor (total-seconds / 3600)
  let minutes floor ((total-seconds mod 3600) / 60)
  let seconds total-seconds mod 60

  let formatted-hours (ifelse-value (hours < 10) [word "0" hours] [hours])
  let formatted-minutes (ifelse-value (minutes < 10) [word "0" minutes] [minutes])
  let formatted-seconds (ifelse-value (seconds < 10) [word "0" seconds] [seconds])

  report (word formatted-hours ":" formatted-minutes ":" precision formatted-seconds 0)

  ] [
    report "00:00:00"
  ]
end


to-report solo-runners-formatted-time

  let solo-runners runners with [( group-id = -1 )]
  let avg-finish-time ( ifelse-value (count solo-runners > 0) [mean [finish-time] of solo-runners] [0] )

  ifelse avg-finish-time > 0 [

  let total-seconds avg-finish-time * 60
  let hours floor (total-seconds / 3600)
  let minutes floor ((total-seconds mod 3600) / 60)
  let seconds total-seconds mod 60

  let formatted-hours (ifelse-value (hours < 10) [word "0" hours] [hours])
  let formatted-minutes (ifelse-value (minutes < 10) [word "0" minutes] [minutes])
  let formatted-seconds (ifelse-value (seconds < 10) [word "0" seconds] [seconds])
  report (word formatted-hours ":" formatted-minutes ":" precision formatted-seconds 0)

  ] [
      report "00:00:00"
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
7
277
73
310
Setup
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
92
278
185
311
Start Race
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
14
117
192
150
number-of-runners
number-of-runners
1
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
11
215
205
248
number-of-spectators
number-of-spectators
0
100
49.0
1
1
NIL
HORIZONTAL

CHOOSER
8
46
146
91
race-distance
race-distance
5 10 21 42.2
1

SLIDER
13
168
217
201
percentage-of-solo-runners
percentage-of-solo-runners
0
100
10.0
1
1
NIL
HORIZONTAL

PLOT
950
347
1150
497
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
951
265
1176
310
Group Runners Average Speed
avg-group-runners-speed
2
1
11

MONITOR
952
138
1109
183
Total Runners in Group
total-runners-in-group
17
1
11

MONITOR
1120
139
1249
184
Total Solo Runners
total-solo-runners
17
1
11

MONITOR
1191
264
1423
309
Solo Runners Average Speed
avg-solo-runner-speed
2
1
11

CHOOSER
152
46
292
91
weather
weather
"dry" "wet"
0

MONITOR
950
34
1106
79
Elapsed Distance (km)
average-distance-covered
2
1
11

MONITOR
951
196
1193
241
Group Runners Average Finish Time
group-runners-formatted-time
17
1
11

MONITOR
1205
193
1486
238
Solo Runners Average Finish Time
solo-runners-formatted-time
17
1
11

MONITOR
1118
33
1230
78
Elapsed Laps
average-laps-completed
0
1
11

MONITOR
1238
32
1394
77
Total Elapsed Time
elapsed-time
2
1
11

@#$#@#$#@
## WHAT IS IT?

This simulation investigates the impact of various social dynamics on non-professional runners during road running events. It compares the effectiveness of group running versus solo running under the influences of race distance, weather conditions, external spectators, and individual social susceptibilities. The goal is to examine how these factors affect the performance differences between group and solo runners and the sustainability of running groups under different conditions.

## HOW IT WORKS

The model simulates a running event with agents representing runners and spectators. Each runner’s performance is influenced by dynamic factors including endurance, motivation, and social susceptibility, which change based on interactions and running conditions. Runners can be part of a group or run solo, with their state influencing their motivation and performance metrics. Each lap around the track is assumed to be 1km, with a lap being the distance from the start line(black and white) and back. Each tick measures a second in time.

- **Runner Colors**: 
  - **White**: Indicates solo runners who are not part of any group.
  - **Pink**: Denotes runners who are part of a group.
  - **Violet**: Represents runners with low social susceptibility (within the 25th percentile).
  - **Brown**: Used for runners with average social susceptibility (between the 25th and 75th percentiles).
  - **Orange**: Signifies runners with high social susceptibility (above the 75th percentile).
  - **Red**: Indicates that a runner has dropped out of the race due to exhaustion or low motivation.

Weather conditions (wet or dry) directly impact runners’ speeds, and spectator presence can alter runners' motivation, particularly influencing those who are socially susceptible. The speeds are expressed in m/km (minutes per kilometer), with lower values indicating faster speeds, mimicking real-world amateur running paces. The interplay between motivation and endurance affects runners’ speeds and ultimately their finish times. Additionally, group dynamics can evolve with runners forming or disbanding from groups based on proximity and pace compatibility, which in turn affects their motivation levels and performance outcomes.

Specators are placed on the lawn and cheer runners periodically to emulate real-life cheering. When runners drop out or complete a race, they are placed on the lawn. When group runners drop out of their group their change to a colour that represents their social susceptibility level.

## HOW TO USE IT

1. **Setup**: Prepare the simulation environment, including the running track and initial placement of runners and spectators.
2. **Sliders**: Adjust the number of runners, percentage of solo runners, number of spectators, and race distance.
3. **Switches**: Toggle weather conditions between dry and wet.
4. **Buttons**: Use the 'setup' button to initialize the simulation based on current settings, and the 'go' button to start the simulation.
5. **Monitors and Plots**: Observe key metrics such as average speed, finish times, and group dynamics through the interface's monitors and plots.

## THINGS TO NOTICE

- Observe how group dynamics influence performance outcomes across different weather conditions.
- Notice the effect of spectators on runners with high social susceptibility.
- Track the color changes in runners as they join groups, run solo, or drop out due to low motivation and varying levels of social susceptibility.


## THINGS TO TRY

- Vary the number of spectators and observe changes in runner motivation and performance.
- Experiment with different distributions of solo and group runners.
- Adjust the weather condition to see its direct impact on runners' speeds and overall race dynamics.
- Experiment with short, medium and long distances to see the performance of group and solo runners over various distances.

## EXTENDING THE MODEL

- Introduce varying levels of spectator enthusiasm that could dynamically change throughout the race.
- Implement more complex weather patterns that intermittently affect different parts of the track.
- Add more nuanced social dynamics, such as leadership within groups or rivalry between runners.

## NETLOGO FEATURES

- Utilizes agent-based modeling to simulate complex social interactions and environmental influences on behavior.
- Employs sliders and switches on the interface to dynamically adjust simulation parameters.
- Demonstrates the use of monitors and plots for real-time visualization of simulation outcomes.

## RELATED MODELS

- Wolf Sheep Predation: Similar use of agent-based modeling to explore dynamics within an ecosystem.
- Traffic Grid: Explores how individual behavior affects traffic flow, similar to runners in a race.
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
  <experiment name="Dry weather group runners vs solo runners and no spectators (10km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
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
  <experiment name="Dry weather group runners vs solo runners and no spectators (5km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
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
  <experiment name="Dry weather group runners vs solo runners and no spectators (42.2km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
    <enumeratedValueSet variable="percentage-of-solo-runners">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="race-distance">
      <value value="42.2"/>
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
  <experiment name="Dry weather group runners vs solo runners and no spectators (21km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
    <enumeratedValueSet variable="percentage-of-solo-runners">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="race-distance">
      <value value="21"/>
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
  <experiment name="Dry weather group runners vs solo runners and spectators (5km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
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
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weather">
      <value value="&quot;dry&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dry weather group runners vs solo runners and spectators (10km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
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
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weather">
      <value value="&quot;dry&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dry weather group runners vs solo runners and spectators (21km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
    <enumeratedValueSet variable="percentage-of-solo-runners">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="race-distance">
      <value value="21"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-runners">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-spectators">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weather">
      <value value="&quot;dry&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Dry weather group runners vs solo runners and spectators (42.2km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
    <enumeratedValueSet variable="percentage-of-solo-runners">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="race-distance">
      <value value="42.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-runners">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-spectators">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weather">
      <value value="&quot;dry&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Wet weather group runners vs solo runners and no spectators (5km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
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
      <value value="&quot;wet&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Wet weather group runners vs solo runners and no spectators (10km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
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
      <value value="&quot;wet&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Wet weather group runners vs solo runners and no spectators (21km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
    <enumeratedValueSet variable="percentage-of-solo-runners">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="race-distance">
      <value value="21"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-runners">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-spectators">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weather">
      <value value="&quot;wet&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Wet weather group runners vs solo runners and no spectators (42.2km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
    <enumeratedValueSet variable="percentage-of-solo-runners">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="race-distance">
      <value value="42.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-runners">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-spectators">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weather">
      <value value="&quot;wet&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Wet weather group runners vs solo runners and spectators (5km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
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
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weather">
      <value value="&quot;wet&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Wet weather group runners vs solo runners and spectators (10km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
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
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weather">
      <value value="&quot;wet&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Wet weather group runners vs solo runners and spectators (21km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
    <enumeratedValueSet variable="percentage-of-solo-runners">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="race-distance">
      <value value="21"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-runners">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-spectators">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weather">
      <value value="&quot;wet&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Wet weather group runners vs solo runners and spectators (42.2km)" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>total-runners-in-group</metric>
    <metric>avg-group-runners-finish-time</metric>
    <metric>avg-group-runners-speed</metric>
    <metric>total-socially-suspectible-runners-in-group</metric>
    <metric>socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>socially-suspectible-group-runners-avg-speed</metric>
    <metric>non-socially-suspectible-group-runners-avg-finish-time</metric>
    <metric>non-socially-suspectible-group-runners-avg-speed</metric>
    <metric>total-solo-runners</metric>
    <metric>avg-solo-runner-finish-time</metric>
    <metric>avg-solo-runner-speed</metric>
    <metric>total-solo-socially-suspectible-runners</metric>
    <metric>socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>socially-suspectible-solo-runners-avg-speed</metric>
    <metric>non-socially-suspectible-solo-runners-avg-finish-time</metric>
    <metric>non-social-suspectible-solo-runners-avg-speed</metric>
    <runMetricsCondition>all? runners [finished-race? or dropped-out?]</runMetricsCondition>
    <enumeratedValueSet variable="percentage-of-solo-runners">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="race-distance">
      <value value="42.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-runners">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-spectators">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="weather">
      <value value="&quot;wet&quot;"/>
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
