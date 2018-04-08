var coffee = require('gulp-coffee');
var gulp = require('gulp');

function build() {
  return gulp.src('./src/**/*.coffee', { sourcemaps: true })
    .pipe(coffee({ bare: true }))
    .pipe(gulp.dest('./lib'));
}

gulp.task('default', gulp.series(build));
