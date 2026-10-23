import 'dart:io';

import 'package:api_client/api_client.dart';

/// Репозиторий раздела «cars»: единственное место, где его экраны ходят в API.
class CarsRepository {
  const CarsRepository(this._api);

  final TheWayApi _api;

  /// `GET /cars`.
  Future<List<Car>> list() => _api.cars.listCars();

  /// `POST /cars`: статус `verified` выставляет сервер.
  Future<Car> create(CarInput input) => _api.cars.createCar(body: input);

  /// `PATCH /cars/{id}`: правка авто («Транспортные средства»); `photoFileId: null` — фото не менять.
  Future<Car> update(String id, CarPatch patch) => _api.cars.updateCar(id: id, body: patch);

  /// `DELETE /cars/{id}`.
  Future<void> delete(String id) => _api.cars.deleteCar(id: id);

  /// `POST /files` (multipart): id файла для `photoFileId` или документа.
  Future<String> upload(File file) async => (await _api.files.uploadFile(file: file)).id;

  /// `POST /cars/{id}/documents`: СТС.
  Future<Car> addSts(String carId, String fileId) =>
      _api.cars.addCarDocument(id: carId, body: CarDocumentInput(fileId: fileId, kind: CarDocumentKind.sts));
}
