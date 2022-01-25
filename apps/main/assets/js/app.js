// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.scss";

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html";
import "alpinejs";
import "./livesocket.js"
import { Collection } from "formex";
Collection.run();

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"

window.onload = () => {
  const removeElement = ({ target }) => {
    console.log("should've removed an item");
    let el = document.getElementById(target.dataset.id);
    let li = el.parentNode;
    li.parentNode.removeChild(li);
  };
  Array.from(document.querySelectorAll(".remove-form-field")).forEach((el) => {
    el.onclick = (e) => {
      removeElement(e);
    };
  });
  Array.from(document.querySelectorAll(".add-form-field")).forEach((el) => {
    el.onclick = ({ target: { dataset } }) => {
      let container = document.getElementById(dataset.container);
      let index = container.dataset.index;
      let newRow = dataset.prototype;
      container.insertAdjacentHTML(
        "beforeend",
        newRow.replace(/__name__/g, index)
      );
      container.dataset.index = parseInt(container.dataset.index) + 1;
      container.querySelector("a.remove-form-field").onclick = (e) => {
        removeElement(e);
      };
    };
  });
};

import Choices from 'choices.js';
if (document.getElementsByClassName('choicesjs').length) {
  Array.from(document.querySelectorAll(".choicesjs")).forEach((el) => {
    new Choices(el);
  });
}
