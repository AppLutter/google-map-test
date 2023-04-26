import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_map_practice/const.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' hide LatLng;

import 'enum_marker_category.dart';
import 'no_glow_behavior.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late TextEditingController textEditingController;
  GoogleMapController? mapController;
  Position? currentPosition;
  bool isLoading = false;
  bool isSearching = false;
  final Set<Marker> _markers = {};
  List<AutocompletePrediction> searchResults = [];
  late final FlutterGooglePlacesSdk places;

  Future<void> fetchMyLocation() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        currentPosition = await Geolocator.getCurrentPosition();
      } else {
        throw (Exception());
      }
    } catch (e) {
      currentPosition = const Position(
        longitude: 126.734086,
        latitude: 37.715133,
        timestamp: null,
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    if (mapController != null) {
      final latLng = LatLng(currentPosition!.latitude, currentPosition!.longitude);
      await mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 15.0),
      );
      setMarker(markerCategory: EnumMarkerCategory.myLocation, latLng: latLng);
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> setMarker({
    required EnumMarkerCategory markerCategory,
    required LatLng latLng,
    String? addressName,
  }) async {
    final marker = Marker(
      markerId: MarkerId(markerCategory.name),
      position: latLng,
      infoWindow: InfoWindow(
        title: addressName ?? markerCategory.ko,
      ),
    );

    setState(() {
      _markers.add(marker);
    });

    /// 마커 등록 오류나서 넣음
    await Future.delayed(const Duration(milliseconds: 1000));
    mapController!.showMarkerInfoWindow(marker.markerId);
  }

  Future<void> searchAddress(String? keyword) async {
    if (keyword == null) {
      return;
    }

    setState(() {
      isSearching = true;
    });
    final predictions = await places.findAutocompletePredictions(
      keyword,
    );
    setState(() {
      searchResults = List.from(predictions.predictions);
      isSearching = false;
    });
  }

  Future<void> moveToResultLocation(AutocompletePrediction searchResult) async {
    try {
      final data = await places.fetchPlace(
        searchResult.placeId,
        fields: [PlaceField.Location],
      );

      final LatLng latLng = LatLng(data.place!.latLng!.lat, data.place!.latLng!.lng);
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 16.0),
      );

      setMarker(markerCategory: EnumMarkerCategory.result, latLng: latLng);
    } catch (e) {
      Fluttertoast.showToast(msg: '위치를 로드하는데 실패했습니다.');
    }
  }

  @override
  void initState() {
    super.initState();
    places = FlutterGooglePlacesSdk(placeKey);
    textEditingController = TextEditingController();
    Future.microtask(() async {
      await fetchMyLocation();
    });
  }

  @override
  void dispose() {
    super.dispose();
    mapController?.dispose();
    textEditingController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _buildBody(),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
      floatingActionButton: currentPosition == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: FloatingActionButton(
                onPressed: () {
                  if (!isLoading) {
                    fetchMyLocation();
                  }
                },
                child: const Icon(Icons.gps_fixed),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (currentPosition == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 20.0,
            ),
            child: Column(
              children: [
                TextField(
                  controller: textEditingController,
                  onSubmitted: (keyword) {
                    searchAddress(keyword);
                  },
                  decoration: InputDecoration(
                    label: const Text('주소를 입력하세요'),
                    labelStyle: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w600,
                    ),
                    fillColor: Colors.lightBlueAccent.withOpacity(0.3),
                    filled: true,
                    border: const OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 1),
                Expanded(
                  child: Stack(
                    children: [
                      _AddressListViewer(
                        searchResults: searchResults,
                        moveToResultLocation: moveToResultLocation,
                      ),
                      if (isSearching)
                        Container(
                          color: Colors.white,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  '검색중',
                                  style: TextStyle(fontSize: 15.0, color: Colors.blue),
                                ),
                                SizedBox(height: 10.0),
                                CircularProgressIndicator(),
                              ],
                            ),
                          ),
                        )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                markers: _markers,
                mapType: MapType.normal,
                onMapCreated: (newMapController) {
                  mapController = newMapController;
                },
                initialCameraPosition: CameraPosition(
                  target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                  zoom: 12.0,
                ),
              ),
              if (isLoading)
                SizedBox.expand(
                  child: Container(
                    alignment: Alignment.center,
                    color: Colors.blue.withOpacity(0.3),
                    child: const CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddressListViewer extends StatelessWidget {
  const _AddressListViewer({
    Key? key,
    required this.searchResults,
    required this.moveToResultLocation,
  }) : super(key: key);
  final List<AutocompletePrediction> searchResults;
  final Function(AutocompletePrediction searchResult) moveToResultLocation;

  @override
  Widget build(BuildContext context) {
    if (searchResults.isEmpty) {
      return const Center(
        child: Text('검색 결과가 없습니다'),
      );
    }

    return ScrollConfiguration(
      /// 오버스크롤 시 나타나는 파란 물결 삭제
      behavior: NoGlowBehavior(),
      child: ListView.builder(
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              moveToResultLocation(searchResults[index]);
            },
            child: Container(
              color: Colors.primaries[index % Colors.primaries.length].withOpacity(0.4),
              child: _AddressTile(
                searchResult: searchResults[index],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    Key? key,
    required this.searchResult,
  }) : super(key: key);
  final AutocompletePrediction searchResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 13,
          ),
          child: Row(
            children: [
              const Icon(Icons.location_city_outlined),
              const SizedBox(width: 10),

              /// Row의 남은 너비만큼만 차지하도록 Expanded를 줌.. 안그러면 overflow 발생
              Expanded(
                child: Text(
                  searchResult.fullText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
