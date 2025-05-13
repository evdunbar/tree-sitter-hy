#!/usr/bin/env hy

(import xml.etree.ElementTree :as ET)

(require hyrule [-> doto meth ncut])
(import catboost :as cb)
(import numpy :as np)
(import pandas :as pd)
(import rdkit [Chem RDLogger])
(import tqdm [tqdm])

(import maplight-gnn)


(defclass DrugBank []
  (setv namespaces {"" "http://www.drugbank.ca"})

  (defmacro ap-find [element name if-found]
    `(do
       (setv it (.find ~element ~name self.namespaces))
       (if-let it ~if-found)))

  (defmacro if-let [maybe execute]
    `(when (is-not ~maybe None)
       ~execute))

  (meth __init__ [@filename @ids @id-types names]
    (setv @names (.str.lower names))
    (setv @get-ids {"ChEBI" @chebi
                    "ChEMBL" @chembl
                    "drugbank-id" @drugbank
                    "InChIKey" @inchikey
                    "PubChem Compound" @pubchem-compound
                    "PubChem Substance" @pubchem-substance
                    "unii" @unii}))

  (meth get-matches []
    (for [#(_ element) (tqdm (ET.iterparse @filename ["end"]))]
      ;; don't care about non-drug entries
      (when (!= (cut element.tag 24 None) "drug")
        (continue))
      (setv matches (@check-match element))
      ;; make sure there are matches before doing more work
      (when (not (matches.any))
        (continue))
      (yield #(matches element))))

  (meth check-match [element]
    (setv matches (pd.Series False :index @ids.index))
    (for [#(id-type id-func) (.items @get-ids)]
      (setv id-val (id-func element))
      (when (is id-val None) (continue))
      (setv id-matches (& (= @id-types id-type) (= @ids id-val)))
      (setv matches (| matches id-matches)))
    ;; names can't use the same logic as the other id types
    (setv #(generic-names brand-names) (@all-names element))
    (setv matches (| matches (@names.isin generic-names)))
    (setv matches (| matches (@names.isin brand-names)))
    (return matches))

  (meth all-names [element]
    (setv generic-names (set))
    (setv brand-names (set))
    (setv main-name (@name element))
    (when (is-not main-name None) (generic-names.add (.lower main-name)))
    (ap-find element "synonyms"
      (for [synonym (.iter it)]
        (when (and (is-not synonym None) (is-not synonym.text None))
          (generic-names.add (.lower synonym.text)))))
    (ap-find element "products"
      (for [product (.iter it)]
        (setv brand-name (product.find "name" @namespaces))
        (if-let brand-name (brand-names.add (.lower brand-name.text)))))
    (setv generic-names (tuple (filter (fn [s] (not-in "\n" s)) generic-names)))
    (setv brand-names (tuple (filter (fn [s] (not-in "\n" s)) brand-names)))
    (return #(generic-names brand-names)))

  (meth cas-number [element]
    (ap-find element "cas-number" it.text))

  (meth chebi [element]
    (@from-external-identifiers element "ChEBI"))

  (meth chembl [element]
    (@from-external-identifiers element "ChEMBL"))

  (meth drugbank [element]
    (ap-find element "drugbank-id" it.text))

  (meth fda-approval [element]
    (ap-find element "groups" (in "approved" (tuple (it.itertext)))))

  (meth inchikey [element]
    (@from-calculated-properties element "InChIKey"))

  (meth indication [element]
    (ap-find element "indication" it.text))

  (meth mechanism [element]
    (ap-find element "mechanism-of-action" it.text))

  (meth name [element]
    (ap-find element "name" it.text))

  (meth prices [element]
    (ap-find element "prices"
      (do
        (setv prices (list))
        (for [price-element (it.iterfind "price" @namespaces)]
          (setv price (price-element.find "cost" @namespaces))
          (if-let price (.append prices (+ price.text (price.attrib.get "currency")))))
        (return prices))))

  (meth pubchem-compound [element]
    (@from-external-identifiers element "PubChem Compound"))

  (meth pubchem-substance [element]
    (@from-external-identifiers element "PubChem Substance"))

  (meth smiles [element]
    (@from-calculated-properties element "SMILES"))

  (meth unii [element]
    (ap-find element "unii" it.text))

  (meth from-external-identifiers [element resource-type]
    (ap-find element "external-identifiers"
      (for [external-identifier (it.iterfind "external-identifier" @namespaces)]
        (when (= (external-identifier.findtext "resource" :namespaces @namespaces) resource-type)
          (return (external-identifier.findtext "identifier" :namespaces @namespaces))))))

  (meth from-calculated-properties [element kind-type]
    (ap-find element "calculated-properties"
      (for [property (it.iterfind "property" @namespaces)]
        (when (= (property.findtext "kind" :namespaces @namespaces) kind-type)
          (return (property.findtext "value" :namespaces @namespaces)))))))


(defclass DataAugmenter []
  (defmacro create-var-column [var-name col-name col-initial-value]
    `(do
       (setv ~var-name ~col-name)
       (setv (get self.drug-list ~var-name) ~col-initial-value)))

  (meth __init__ [@filename]
    (setv @drug-list None)
    (setv @admet-models None))

  (meth load-drug-queries []
    (cond
      (@filename.endswith ".csv")
      (with [f (open @filename "r")]
        (setv @drug-list (pd.read-csv f)))
      (@filename.endswith ".json")
      (with [f (open @filename "r")]
        (setv @drug-list (pd.read-json f :orient "records")))
      True
      (raise (ValueError "Data file must be .csv or .json")))
    (return self))

  (meth load-admet-models [models]
    (setv @admet-models (dict))
    (for [#(name path) (models.items)]
      (setv model (cb.CatBoostClassifier))
      (model.load-model path)
      (setv (get @admet-models name) model))
    (return self))

  (meth save-drug-info [filename]
    (when (is @drug-list None)
      (raise (ValueError "drug-list must be loaded first.")))
    (with [f (open filename "w")]
      (@drug-list.to-json f :orient "records")))

  (meth match-drugbank [filename id-col-name id-type-col-name name-col-name]
    (when (is @drug-list None)
      (raise (ValueError "drug-list is not defined. Call load-drug-queries before match-drugbank.")))
    ;; make sure the cols are strings and not lists of strings
    (setv unwrap-list (fn [x] (if (isinstance x list) (get x 0) x)))
    (setv id-col (.apply (get @drug-list id-col-name) unwrap-list))
    (setv id-type-col (.apply (get @drug-list id-type-col-name) unwrap-list))
    (setv name-col (.apply (get @drug-list name-col-name) unwrap-list))
    ;; tedious column making for what we're about to store
    ;; variable name, column title, initial value
    (create-var-column cas-column "CAS Registry Number" None)
    (create-var-column fda-column "FDA Approved" None)
    (create-var-column indication-column "Indication" None)
    (create-var-column mechanism-column "Mechanism" None)
    (create-var-column name-column "DrugBank Name" None)
    (create-var-column price-column "Prices" (@drug-list.apply (fn [_] (list)) :axis 1))
    (create-var-column smiles-column "SMILES" None)
    (create-var-column unii-column "UNII" None)
    (setv drugbank (DrugBank filename id-col id-type-col name-col))
    (for [#(matches element) (drugbank.get-matches)]
      (setv (ncut @drug-list.loc matches cas-column) (drugbank.cas-number element))
      (setv (ncut @drug-list.loc matches fda-column) (drugbank.fda-approval element))
      (setv (ncut @drug-list.loc matches indication-column) (drugbank.indication element))
      (setv (ncut @drug-list.loc matches mechanism-column) (drugbank.mechanism element))
      (setv (ncut @drug-list.loc matches name-column) (drugbank.name element))
      (setv (ncut @drug-list.loc matches price-column)
        (.apply (ncut @drug-list.loc matches price-column) (fn [_] (drugbank.prices element)))) ; prices is a list
      (setv (ncut @drug-list.loc matches smiles-column) (drugbank.smiles element))
      (setv (ncut @drug-list.loc matches unii-column) (drugbank.unii element))))

  (meth deduplicate []
    (when (is @drug-list None)
      (raise (ValueError "drug-list is not defined. Call load-drug-queries before deduplicate.")))
    (when (not-in "DrugBank Name" @drug-list.columns)
      (raise (ValueError "ID data does not exist yet. Run match-drugbank to create it.")))
    (setv @drug-list
      (-> @drug-list
        (.groupby "DrugBank Name")
        (.agg
          (fn [x]
            (setv y [])
            (for [item x]
              (if (isinstance item list)
                (y.extend item)
                (y.append item)))
            (setv z (set y))
            (z.discard None)
            (cond
              (= (len z) 0) None
              (= (len z) 1) (.pop z)
              True z)))
        (.reset-index))))

  (meth predict-admet []
    (when (is @drug-list None)
      (raise (ValueError "drug-list is not defined. Call load-drug-queries before predict-admet.")))
    (when (is @admet-models None)
      (raise (ValueError "admet-models is not defined. Call load-admet-models before predict-admet.")))
    (when (not-in "SMILES" @drug-list.columns)
      (raise (ValueError "SMILES data does not exist yet. Run match-drugbank to create it.")))
    (RDLogger.DisableLog "rdApp.*")
    (setv smiles-mask (.notna (get @drug-list "SMILES")))
    (setv smiles (ncut @drug-list.loc smiles-mask "SMILES"))
    (setv molecules (smiles.apply Chem.MolFromSmiles))
    (setv molecules-mask (.notna molecules))
    (setv fingerprints (@get-fingerprints (get molecules molecules-mask)))
    (setv combined-mask (pd.Series False :index @drug-list.index))
    (setv (ncut combined-mask.loc (. (get smiles molecules-mask) index)) True)
    (for [#(name model) (@admet-models.items)]
      (setv predictions (model.predict-proba fingerprints))
      (setv (ncut @drug-list.loc combined-mask name) (ncut predictions : 1))))

  (meth get-fingerprints [molecules]
    (setv fingerprints (list))
    (fingerprints.append (maplight-gnn.get-morgan-fingerprints molecules))
    (fingerprints.append (maplight-gnn.get-avalon-fingerprints molecules))
    (fingerprints.append (maplight-gnn.get-erg-fingerprints molecules))
    (fingerprints.append (maplight-gnn.get-rdkit-features molecules))
    (fingerprints.append (maplight-gnn.get-gin-supervised-masking molecules))
    (np.concatenate fingerprints :axis 1)))


(when (= __name__ "__main__")
  (setv augmenter
    (-> (DataAugmenter "data/translator_drugs.json")
      (.load-drug-queries)
      (.load-admet-models {"Blood Brain Barrier" "data/admet/bbb_martins-0.916-0.002.dump" "Bioavailability" "data/admet/bioavailability_ma-0.74-0.01.dump" "Human Intestinal Absorption" "data/admet/hia_hou-0.989-0.001.dump"})))
  (doto augmenter
    (.match-drugbank "data/src/drugbank.xml" "result_id" "id_type" "result_name")
    (.deduplicate)
    (.predict-admet)
    (.save-drug-info "data/translator_drug_list.json")))
