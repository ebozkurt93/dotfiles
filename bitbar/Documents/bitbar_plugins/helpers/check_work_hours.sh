# default to exit on all times if on vacation
if [ -f ~/Documents/bitbar_plugins/tmp/holiday ]; then
exit 1
fi

if [ ! -f ~/Documents/bitbar_plugins/tmp/work ]; then
  case "$(date +%a)" in 
    Sat|Sun) exit 1;; # Do not show these repos at weekend
  esac

  # check if we are in or close to workhours
  H=$(date +%H | sed 's/^0*//')
  if !((7 <= H && H < 17)); then
    exit 1
  fi
fi