path = require 'path'
#fs = require 'fs-extra'
exec = require('child_process').exec

gulp = require 'gulp'
r = require 'request'

browserSync = require 'browser-sync'

browserify = require 'browserify'
exorcist = require 'exorcist'
#coffeeify = require 'coffeeify'
#bd = require 'browserify-data'

source = require('vinyl-source-stream')
transform = require 'vinyl-transform'

less = require 'gulp-less'
#clean = require 'gulp-clean'
#zopfli = require 'gulp-zopfli'
rename = require 'gulp-rename'
uglify = require 'gulp-uglify'
gdata = require 'gulp-data'
debug = require 'gulp-debug'
deploy = require 'gulp-gh-pages'
runSequence = require 'run-sequence'
markdown = require 'gulp-markdown-to-json'
yaml = require 'gulp-yaml'

serverData = require './serverData'

# Default gulp tasks watches files for changes
gulp.task "default", ['serverData', 'browser-sync'], ->
  gulp.watch './app/**/*.*', ['templates', browserSync.reload]
  gulp.watch "styles/*.less", ["styles", browserSync.reload]
  gulp.watch 'static/**', ['static', browserSync.reload]
  gulp.watch './content/**/*.md', ['content', browserSync.reload]
  gulp.watch './content/**/*.yaml', ['data', browserSync.reload]
  return

# For development.
gulp.task "browser-sync", ['templates', 'styles', 'static'], ->
  browserSync
    server:
      baseDir: 'public'
    logConnections: true
    injectChanges: false
    #logLevel: 'debug'
  return

# This generate js app file.
gulp.task 'compile', ->
  browserified = transform (filename) ->
    b = browserify {debug: true, extensions: ['.cjsx', '.coffee']}
    b.add filename
    #b.transform 'coffee-reactify'
    b.bundle()


  gulp.src 'app/app.cjsx'
    .pipe browserified
    # Extract the map.
    .pipe transform(-> exorcist('./public/assets/app.js.map'))
    # Shrink the codebase.
    .pipe uglify()
    # Rename the file.
    .pipe rename('app.js')
    .pipe gulp.dest('./public/assets')

# Convert yaml files from the content dir to json files.
gulp.task 'data', ->
  gulp.src './content/**/*.yaml'
    .pipe yaml()
    .pipe gulp.dest('./app/data/')

# Convert markdown files from content dir to json files.
gulp.task 'content', ->
  gulp.src './content/**/*.md'
    .pipe markdown()
    .pipe gulp.dest('./app/data/')

gulp.task 'serverData', ['data'], (cb) ->
  serverData cb

# Compile the static html files.
gulp.task 'templates', ['compile'], (cb) ->
  # Calling an external script for this.
  exec 'coffee ./scripts/renderMarkup.coffee', (err, stdout, stderr) ->
    console.log stdout
    console.log stderr
    cb err

# Process LESS to CSS.
gulp.task 'styles', ->
  gulp.src(["styles/app.less", 'styles/print.less', 'styles/iefix.less'])
    .pipe less()
    .pipe gulp.dest("./public/assets")

# Copy static files.
gulp.task 'static', ->
  gulp.src('./static/**')
    .pipe gulp.dest('./public/')

# - - - - prod - - - -

gulp.task 'deploy', (cb) ->
  runSequence ['static', 'styles', 'serverData'],
    'templates', 'gh-pages', cb

gulp.task 'gh-pages', ->
  gulp.src './public/**/*'
    .pipe deploy cacheDir: './tmp'

# gulp.task 'templatesProd', ->
#   exec('coffee gulp/compileProd.coffee')

gulp.task 'set_sha', (cb) ->
  r_ops =
    uri: 'https://api.github.com/repos/cape-io/mica.ezle.io/branches/master'
    json: true
    headers:
      'user-agent': 'request.js'
  r r_ops, (err, response, body) ->
    if err then throw err
    global.sha = body.commit.sha
    fs.outputJsonSync 'app/data/commit.json', body.commit
    cb()
  return

# Remove contents from prod directory.
gulp.task 'prod_clean', ->
  gulp.src('./public', read: false)
    .pipe(clean())

gulp.task 'copy_css', ['styles'], ->
  gulp.src('./dev/app.css')
    .pipe(rename(global.sha+'.css'))
    .pipe(gulp.dest('./prod'))
  gulp.src('./dev/print.css')
    .pipe(gulp.dest('./prod'))

gulp.task 'compress', ->
  gulp.src("./prod/*.{js,css,html,json}")
    .pipe(zopfli())
    .pipe(gulp.dest("./prod"))