(ns very-simple-project.core
  (:require
   [very-simple-project.util :as util]))

(defn main
  []
  (util/number->str 5))
