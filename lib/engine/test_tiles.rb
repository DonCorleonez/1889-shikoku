# frozen_string_literal: true

module Engine
  module TestTiles
    # each entry is a Hash containing:
    # - tile / hex id
    # - game title (optional)
    # - fixture (optional, requires game title; if not given, the starting state
    #   of the hex/tile is used)
    # - action id (optional, requires fixture; if not given, the fixture is
    #   processed to its conclusion)
    # - other kwargs for View::Tiles#render_tile_blocks
    TEST_TILES_HUMAN_READABLE = [
      { tile: '45' },
      { tile: 'K4', title: '1889' },
    ].freeze

    # rearrange the above to a structure that can be more efficiently iterated
    # over--each fixture only needs to be fetched once, and only needs to be
    # processed to each unique action once
    #
    # defining with this structure directly would confusing to read; for generic
    # tiles, all of the keys in the nested Hash would end up as `nil`
    TEST_TILES =
      TEST_TILES_HUMAN_READABLE.each_with_object({}) do |opts, test_tiles|
        tile = opts.delete(:tile)
        title = opts.delete(:title)
        fixture = opts.delete(:fixture)
        action = opts.delete(:action)

        test_tiles[title] ||= {}
        test_tiles[title][fixture] ||= {}
        test_tiles[title][fixture][action] ||= []

        test_tiles[title][fixture][action] << [tile, opts]
      end.freeze
  end
end
