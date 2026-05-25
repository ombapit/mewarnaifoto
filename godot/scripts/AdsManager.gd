extends Node

# Set false saat rilis ke Play Store (pakai ID asli).
# true = pakai test ID Google (wajib saat dev biar akun AdMob tak kena flag).
const USE_TEST_ADS := false

const BANNER_ID_REAL := "ca-app-pub-4996771710266006/3645387104"
const INTER_ID_REAL := "ca-app-pub-4996771710266006/7712624627"

const BANNER_ID_TEST := "ca-app-pub-3940256099942544/6300978111"
const INTER_ID_TEST := "ca-app-pub-3940256099942544/1033173712"

const INTER_MIN_GAP := 90.0  # detik antar interstitial

var _ready_ads := false
var _want_banner := false
var _banner: AdView = null
var _interstitial: InterstitialAd = null
var _last_inter := -1000.0


func _banner_id() -> String:
	return BANNER_ID_TEST if USE_TEST_ADS else BANNER_ID_REAL


func _inter_id() -> String:
	return INTER_ID_TEST if USE_TEST_ADS else INTER_ID_REAL


func _ready() -> void:
	if OS.get_name() != "Android":
		return
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_init_done

	var cfg := RequestConfiguration.new()
	# Wajib untuk app anak (COPPA): iklan family-safe saja
	cfg.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.TRUE
	cfg.tag_for_under_age_of_consent = RequestConfiguration.TagForUnderAgeOfConsent.TRUE
	cfg.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G

	MobileAds.set_request_configuration(cfg)
	MobileAds.initialize(listener)
	print("[Ads] MobileAds.initialize dipanggil (test=%s)" % USE_TEST_ADS)


func _on_init_done(_status) -> void:
	print("[Ads] init done")
	_ready_ads = true
	_load_interstitial()
	if _want_banner:
		_do_show_banner()


# --- Banner ---

func show_banner() -> void:
	_want_banner = true
	if _ready_ads:
		_do_show_banner()
	else:
		print("[Ads] banner ditunda, init belum selesai")


func _do_show_banner() -> void:
	if _banner == null:
		_banner = AdView.new(_banner_id(), AdSize.BANNER, AdPosition.Values.BOTTOM)
		_banner.ad_listener.on_ad_loaded = func():
			print("[Ads] banner LOADED")
			if _want_banner:
				_banner.show()
		_banner.ad_listener.on_ad_failed_to_load = func(err):
			print("[Ads] banner GAGAL: ", err.message if err else "?")
		_banner.load_ad(AdRequest.new())
		print("[Ads] banner dibuat & load dipanggil")
	_banner.show()


func hide_banner() -> void:
	_want_banner = false
	if _banner:
		_banner.hide()


# --- Interstitial ---

func _load_interstitial() -> void:
	if not _ready_ads:
		return
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd):
		_interstitial = ad
	cb.on_ad_failed_to_load = func(_err):
		_interstitial = null
	var loader := InterstitialAdLoader.new()
	loader.load(_inter_id(), AdRequest.new(), cb)


func try_show_interstitial() -> void:
	if _interstitial == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_inter < INTER_MIN_GAP:
		return
	_last_inter = now
	_interstitial.show()
	_interstitial = null
	_load_interstitial()  # preload berikutnya
