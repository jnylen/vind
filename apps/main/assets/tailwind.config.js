const colors = require('tailwindcss/colors')

module.exports = {
  content: [
    "../lib/main/templates/**/*.html.eex",
    "../lib/main/templates/**/*.html.leex",
    "../lib/main/live/**/*.html.leex",
  ],
  theme: {
    extend: {
      colors: {
        code: {
          green: "#b5f4a5",
          yellow: "#ffe484",
          purple: "#d9a9ff",
          red: "#ff8383",
          blue: "#93ddfd",
          white: "#ffffff",
        },
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
  ],
};
