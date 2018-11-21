{exec} = require("child_process")

task("build", "Build project from src/*.coffee to lib/*.js.", () ->
  exec("coffee --compile --output lib/ src/", (err, stdout, stderr) ->
    if err?
      throw err
    console.log("coffee --compile --output lib/ src/")
    if stdout? or stderr?
      console.log(stdout + stderr)
  )
)

task("watch", "Watch project from src/*.coffee to lib/*.js.", () ->
  exec("coffee --compile --watch --output lib/ src/", (err, stdout, stderr) ->
    if err?
      throw err
    console.log("coffee --compile --watch --output lib/ src/")
    if stdout? or stderr?
      console.log(stdout + stderr)
  )
)
