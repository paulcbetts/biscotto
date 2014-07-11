fs      = require 'fs'
path    = require 'path'

{inspect} = require 'util'
walkdir = require 'walkdir'
Biscotto = require '../src/biscotto'
Parser  = require '../src/parser'
Metadata = require '../src/metadata'

{diff}    = require 'jsondiffpatch'
_         = require 'underscore'
_.str     = require 'underscore.string'

require 'jasmine-focused'

describe "Metadata", ->
  parser = null

  constructDelta = (filename, hasReferences = false) ->
    source = fs.readFileSync filename, 'utf8'

    Biscotto.slugs = {}
    parser.parseContent source, filename
    metadata = new Metadata(filename, {}, parser.classes, parser.files)
    metadata.generate(CoffeeScript.nodes(source))
    generated = Biscotto.populateSlug(filename, metadata)
    Biscotto.slugs = {} # reset the slugs

    expected_filename = filename.replace(/\.coffee$/, '.json')
    expected = JSON.stringify(JSON.parse(fs.readFileSync expected_filename, 'utf8'), null, 2)
    generated =  JSON.stringify(generated, null, 2)

    checkDelta(expected_filename, expected, generated, diff(expected, generated))

  checkDelta = (expected_filename, expected, generated, delta) ->
    if delta?
      if process.env.BISCOTTO_DEBUG
        fs.writeFileSync(expected_filename, generated + "\n")
      else
        console.error expected, generated
        console.error(delta)
        expect(delta).toBe(undefined)

  beforeEach ->
    parser = new Parser({
      inputs: []
      output: ''
      extras: []
      readme: ''
      title: ''
      quiet: false
      private: true
      verbose: true
      metadata: true
      github: ''
    })

  describe "Classes", ->
    it 'understands descriptions', ->
      constructDelta("spec/metadata_templates/classes/basic_class.coffee")

    it 'understands class properties', ->
      constructDelta("spec/metadata_templates/classes/class_with_class_properties.coffee")

    it 'understands prototype properties', ->
      constructDelta("spec/metadata_templates/classes/class_with_prototype_properties.coffee")

  describe "Exports", ->
    it 'understands basic exports', ->
      constructDelta("spec/metadata_templates/exports/basic_exports.coffee")

    it 'understands class exports', ->
      constructDelta("spec/metadata_templates/exports/class_exports.coffee")

  describe "Requires", ->
    it 'understands basic requires', ->
      constructDelta("spec/metadata_templates/requires/basic_requires.coffee")

    it 'understands importing', ->
      constructDelta("spec/metadata_templates/requires/references/buffer-patch.coffee")

  describe "A real package", ->
    package_json = null
    test_path = null

    beforeEach ->
      test_path = path.join("spec", "metadata_templates", "test_package")
      package_json_path = path.join(test_path, 'package.json')
      package_json = JSON.parse(fs.readFileSync(package_json_path, 'utf-8'))
      for file in fs.readdirSync(path.join(test_path, "lib"))
        parser.parseFile path.join(test_path, "lib", file)

    fit "renders the package correctly", ->
      # TODO: this is the block from Biscotto. should it be abstracted better?
      metadata = new Metadata(package_json["main"], package_json["dependencies"], parser.classes, parser.files)
      for filename, content of parser.iteratedFiles
        # TODO: @lineMapping is all messed up; try to avoid a *second* call to .nodes
        metadata.generate(CoffeeScript.nodes(content))
        Biscotto.populateSlug(filename, metadata)

      expected_filename = path.join(test_path, 'test_metadata.json')
      expected = JSON.stringify(JSON.parse(fs.readFileSync expected_filename, 'utf8'), null, 2)
      generated =  JSON.stringify(Biscotto.slugs, null, 2)

      checkDelta(expected_filename, expected, generated, diff(expected, generated))
