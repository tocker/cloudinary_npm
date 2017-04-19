expect = require('expect.js')
cloudinary = require('../cloudinary')
helper = require("./spechelper")
Q = require('q')

SUFFIX = helper.SUFFIX
PUBLIC_ID_PREFIX = "npm_api_test"
PUBLIC_ID = PUBLIC_ID_PREFIX + SUFFIX
PUBLIC_ID_1 = PUBLIC_ID + "_1"
PUBLIC_ID_2 = PUBLIC_ID + "_2"
PUBLIC_ID_3 = PUBLIC_ID + "_3"
TEST_TAG = 'npm_advanced_search'

describe "search_api", ->
  describe "unit", ->
    it 'should create empty json',->
     query_hash = cloudinary.v2.search.instance().to_query()
     expect(query_hash).to.eql({})

    it 'should always return same object in fluent interface',->
      instance = cloudinary.v2.search.instance()
      for method in ['expression','sort_by','max_results','next_cursor','aggregate','includes'] 
        same_instance = instance[method]('emptyarg')
        expect(instance).to.eql(same_instance)

    it 'should add expression to query',->
      query = cloudinary.v2.search.expression('format:jpg').to_query()
      expect(query).to.eql(expression: 'format:jpg')

    it 'should add sort_by to query',->
      query = cloudinary.v2.search.sort_by('created_at', 'asc').sort_by('updated_at', 'desc').to_query()
      expect(query).to.eql(sort_by: [{ created_at : 'asc' }, { updated_at : 'desc' }])

    it 'should add max_results to query',->
      query = cloudinary.v2.search.max_results('format:jpg').to_query()
      expect(query).to.eql(max_results: 'format:jpg')


    it 'should add next_cursor to query',->
      query = cloudinary.v2.search.next_cursor('format:jpg').to_query()
      expect(query).to.eql(next_cursor: 'format:jpg')


    it 'should add facets arguments as array to query',->
      query = cloudinary.v2.search.aggregate('format', 'size_category').to_query()
      expect(query).to.eql(aggregate: ['format', 'size_category'])


    it 'should add includes to query',->
      query = cloudinary.v2.search.includes('context', 'tags').to_query()
      expect(query).to.eql(include: ['context', 'tags'])

  describe "integration", ->
    before (done) ->
      @timeout helper.TIMEOUT_LONG

      Q.allSettled [
        cloudinary.v2.api.delete_resources_by_tag(TEST_TAG),
        cloudinary.v2.uploader.upload(helper.IMAGE_FILE, public_id: PUBLIC_ID_1, tags: [helper.UPLOAD_TAGS...,TEST_TAG], context: "stage=in_review")
        cloudinary.v2.uploader.upload(helper.IMAGE_FILE, public_id: PUBLIC_ID_2, tags: [helper.UPLOAD_TAGS...,TEST_TAG], context: "stage=new")
        cloudinary.v2.uploader.upload(helper.IMAGE_FILE, public_id: PUBLIC_ID_3, tags: [helper.UPLOAD_TAGS...,TEST_TAG], context: "stage=validated")]
      .finally ->
        setTimeout(done,2000)

    after (done)->
      @timeout helper.TIMEOUT_LONG
      if cloudinary.config().keep_test_products
        done()
      else
        config = cloudinary.config()
        if(!(config.api_key && config.api_secret))
          expect().fail("Missing key and secret. Please set CLOUDINARY_URL.")

        Q.allSettled [
          cloudinary.v2.api.delete_resources_by_tag TEST_TAG ]
          .finally ->
        done()


    it "should return all images tagged with #{TEST_TAG}",->
      cloudinary.v2.search.expression("tags:#{TEST_TAG}").execute (err,results)->
        expect(results['resources'].length).to.eql(3)

    it "should return resource #{PUBLIC_ID_1}",->
      cloudinary.v2.search.expression("public_id:#{PUBLIC_ID_1}").execute (err,results)->
        expect(results['resources'].length).to.eql(1)


    it 'should paginate resources limited by tag and orderd by ascing public_id',->
      instance = cloudinary.v2.search.max_results(1).expression("tags:#{TEST_TAG}").sort_by('public_id', 'asc')
      instance.execute  (err,results)->
        expect(results['resources'].length).to.eql( 1 )
        expect(results['resources'][0]['public_id']).to.eql PUBLIC_ID_1
        expect(results['total_count']).to.eql( 3 )

        cloudinary.v2.search.max_results(1).expression("tags:#{TEST_TAG}").sort_by('public_id', 'asc').next_cursor(results['next_cursor']).execute (err,results)->
          expect(results['resources'].length).to.eql( 1 )
          expect(results['resources'][0]['public_id']).to.eql PUBLIC_ID_2
          expect(results['total_count']).to.eql(3)

          cloudinary.v2.search.max_results(1).expression("tags:#{TEST_TAG}").sort_by('public_id', 'asc').next_cursor(results['next_cursor']).execute (err,results)->
            expect(results['resources'].length).to.eql( 1 )
            expect(results['resources'][0]['public_id']).to.eql PUBLIC_ID_3
            expect(results['total_count']).to.eql(3)

            cloudinary.v2.search.max_results(1).expression("tags:#{TEST_TAG}").sort_by('public_id', 'asc').next_cursor(results['next_cursor']).execute (err,results)->
              expect(results['resources'].length).to.eql( 0 )


    it 'should include context',->
      cloudinary.v2.search.expression("tags:#{TEST_TAG}").includes('context').execute (err,results)->
        expect(results['resources'].length).to.eql( 3 )
        for res in results['resources']
          expect(Object.keys(res['context'])).to.eql ['stage']
      

    it 'should include context, tags and image_metadata',->
      cloudinary.v2.search.expression("tags:#{TEST_TAG}").includes('context', 'tags', 'image_metadata').execute (err,results)->
        expect(results['resources'].length).to.eql( 3 )
        for res in results['resources']
          expect(Object.keys(res['context'])).to.eql ['stage']
          expect(res.image_metadata).to.exist
          expect(res['tags'].length).to.eql ( 4 )
      

