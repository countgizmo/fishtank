(ns core
  (:require
    [clojure.java.io :as io]
    [clojure.string :as str]
    [charred.api :as json]))

(def json-rpc-version "2.0")

(defn add
  [a b]
  (+ a b))
