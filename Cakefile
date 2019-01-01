{exec} = require("child_process")

task("build", "Build project from srcs/*.coffee to libs/*.js.", () ->
  exec("coffee --compile --output libs/ srcs/", (err, stdout, stderr) ->
    if err?
      throw err
    console.log("coffee --compile --output libs/ srcs/")
    if stdout? or stderr?
      console.log(stdout + stderr)
  )
)

task("watch", "Watch project from srcs/*.coffee to libs/*.js.", () ->
  exec("coffee --compile --watch --output libs/ srcs/", (err, stdout, stderr) ->
    if err?
      throw err
    console.log("coffee --compile --watch --output libs/ srcs/")
    if stdout? or stderr?
      console.log(stdout + stderr)
  )
)
