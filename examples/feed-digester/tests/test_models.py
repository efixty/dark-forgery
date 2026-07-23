"""Contract test for the Item schema. Pins the dedupe-id behavior every stage relies on."""

from feed_digester import Item


def test_make_id_is_stable_and_deterministic():
    a = Item.make_id("https://example.com/feed", "guid-123")
    b = Item.make_id("https://example.com/feed", "guid-123")
    assert a == b
    assert len(a) == 64  # sha256 hex


def test_make_id_distinguishes_sources():
    a = Item.make_id("https://a.com/feed", "guid-123")
    b = Item.make_id("https://b.com/feed", "guid-123")
    assert a != b


def test_item_fields_round_trip():
    item = Item(
        id=Item.make_id("https://example.com/feed", "g1"),
        source="example",
        source_type="rss",
        title="Hello",
        url="https://example.com/post/1",
        published="2026-07-23T08:00:00Z",
        summary="A short plain-text summary.",
    )
    assert item.source_type == "rss"
    assert item.published.endswith("Z")
