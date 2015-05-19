module.exports = (grunt) ->

  # configuration
  grunt.initConfig

    # grunt sass
    sass:
      compile:
        options:
          style: 'expanded'
          sourcemap: 'none'
        files: [
          expand: true
          cwd: 'src'
          src: ['**/*.sass', '**/*.scss']
          dest: 'public'
          ext: '.css'
        ]

    # grunt coffee
    coffee:
      compile:
        expand: true
        cwd: 'src'
        src: ['**/*.coffee']
        dest: 'public'
        ext: '.js'
        options:
          bare: true
          # preserve_dirs: true

    # grunt slim
    slim:
      dist:
        options:
          pretty: true
        files: [{
          cwd: 'src'
          dest: 'public'
          expand: true
          src: ['**/*.slim']
          ext: '.html'
        }]

    bake:
      build:
        files: [{
          cwd: 'public'
          src: ['**/*.html']
          dest: 'public'
          expand: true
        }]

    bowercopy:
      options:
        srcPrefix: 'bower_components'
      scripts:
        options:
          destPrefix: 'public/vendor'
        files:
          'jquery/jquery.js': 'jquery/dist/jquery.js'
          'font-awesome/fonts': 'font-awesome/fonts'
          'normalize-css/normalize.css': 'normalize-css/normalize.css'

    # grunt watch (or simply grunt)
    watch:
      html:
        files: ['src/**/*.html']
      sass:
        files: ['src/**/*.sass', 'src/**/*.scss']
        tasks: ['sass']
      coffee:
        files: ['src/**/*.coffee']
        tasks: ['coffee']
      slim:
        files: ['src/**/*.slim']
        tasks: ['slim', 'bake:build']
      options:
        livereload: true

    # grunt connect
    connect:
      server:
        options:
          base: 'public'
          open: true
          port: 8082

  # load plugins
  grunt.loadNpmTasks 'grunt-contrib-sass'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-slim'
  grunt.loadNpmTasks 'grunt-bake'
  grunt.loadNpmTasks 'grunt-bowercopy'
  grunt.loadNpmTasks 'grunt-contrib-connect'

  # tasks
  grunt.registerTask 'default', ['bowercopy', 'sass', 'coffee', 'slim', 'bake', 'connect', 'watch']
