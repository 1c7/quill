/*global module:false*/
module.exports = function(grunt) {

  // Project configuration.
  grunt.initConfig({
    meta: {
      version: '0.1.0',
      banner: '/*! Stypi Editor - v<%= meta.version %> - ' +
        '<%= grunt.template.today("yyyy-mm-dd") %>\n' +
        '* https://www.stypi.com/\n' +
        '* Copyright (c) <%= grunt.template.today("yyyy") %> ' +
        'Jason Chen, Salesforce.com */'
    },
    concat: {
      dist: {
        src: ['<banner:meta.banner>', 'bin/src/*.js'],
        dest: 'build/tandem.js'
      }
    },
    min: {
      dist: {
        src: ['<banner:meta.banner>', '<config:concat.dist.dest>'],
        dest: 'build/tandem.min.js'
      }
    },
    uglify: {}
  });

  // Default task.
  grunt.registerTask('default', 'concat min');

};
