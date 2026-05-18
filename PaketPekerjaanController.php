<?php

namespace App\Http\Controllers;

use App\Imports\PaketPekerjaanImport;
use App\Services\DocumentService;
use App\Services\IndikatorService;
use App\Services\KategoriPaketPekerjaanService;
use App\Services\PaketPekerjaanService;
use App\Services\PelaksanaService;
use App\Services\PenyediaService;
use App\Services\WilayahService;
use Illuminate\Http\Request;

use Illuminate\Support\Str;
use PhpOffice\PhpSpreadsheet\IOFactory;
use Carbon\Carbon;
use Maatwebsite\Excel\Facades\Excel;
use App\Models\PaketPekerjaan;

class PaketPekerjaanController extends IoResourceController
{
    public function __construct()
    {
        $this->service = new PaketPekerjaanService();
        $this->viewPrefix = 'app.admin.paket_pekerjaan';
        $this->itemVariable = 'paket_pekerjaan';

        $wilayahService = new WilayahService();
        $list_provinsi = $wilayahService->search(['kode_in' => ['11', '12', '13']]);
        $list_kabupaten = $wilayahService->search(['parent_kode_in' => $list_provinsi->pluck('kode')->toArray()]);
        $list_kecamatan = $wilayahService->search(['parent_kode_in' => $list_kabupaten->pluck('kode')->toArray()]);

        view()->share('list_provinsi', $list_provinsi);
        view()->share('list_kabupaten', $list_kabupaten);
        view()->share('list_kecamatan', $list_kecamatan);

        view()->share('list_provinsi_options', $wilayahService->dropdown(['kode_in' => ['11', '12', '13']]));
        view()->share('list_kabupaten_options', $wilayahService->dropdown(['parent_kode_in' => $list_provinsi->pluck('kode')->toArray()]));

        $indikatorService = new IndikatorService();
        view()->share('list_indikator', $indikatorService->dropdown(['no_children' => '1', 'with' => ['list_pelaksana']]));
        view()->share('list_indikator_data', $indikatorService->search(['no_children' => '1', 'with' => ['list_pelaksana']]));
        $pelaksanaService = new PelaksanaService();
        view()->share('list_pelaksana', $pelaksanaService->dropdown());

        $kategoriPaketPekerjaanService = new KategoriPaketPekerjaanService();
        view()->share('list_kategori', $kategoriPaketPekerjaanService->dropdown());

        $penyediaService = new PenyediaService();
        view()->share('list_penyedia', $penyediaService->dropdown());
    }

    public function search(Request $request)
    {
        $request->merge([
            'with' => ['pelaksana', 'indikator.parent', 'wilayah.parent.parent', 'kategori_paket_pekerjaan'],
        ]);
        return parent::search($request);
    }

    public function store(Request $request)
    {
        $filename = DocumentService::save_file($request, 'file_foto', 'paket_pekerjaan');
        if ($filename !== '') $request->merge(['foto' => $filename]);

        $filename = DocumentService::save_file($request, 'file_foto_sesudah', 'paket_pekerjaan');
        if ($filename !== '') $request->merge(['foto_sesudah' => $filename]);

        $latitude = $request->input('latitude') ?? '';
        $longitude = $request->input('longitude') ?? '';
        if ($latitude === '' || $longitude === '') $request = $this->getRandomlatitudeLongitude($request);

        return parent::store($request);
    }

    public function update(Request $request, $id)
    {
        $filename = DocumentService::save_file($request, 'file_foto', 'paket_pekerjaan');
        if ($filename !== '') $request->merge(['foto' => $filename]);

        $filename = DocumentService::save_file($request, 'file_foto_sesudah', 'paket_pekerjaan');
        if ($filename !== '') $request->merge(['foto_sesudah' => $filename]);

        $latitude = $request->input('latitude') ?? '';
        $longitude = $request->input('longitude') ?? '';
        if ($latitude === '' || $longitude === '') $request = $this->getRandomlatitudeLongitude($request);

        return parent::update($request, $id);
    }

    public function listWilayahExcel($scope, $children = null) {
        // code...
        if (in_array($scope, [2,3]) && empty($children)) {
            // code...
            abort(404);exit;
        }

        $wilayahService = new WilayahService();

        switch ($scope) {
            case 1:
                // code...
                $list_provinsi = $wilayahService->search(['kode_in' => ['11', '12', '13']]);
                return $list_provinsi->toJson();
                break;

            case 2:
                // code...
                if (strpos($children, '.') > 0) {
                    // code...
                    abort(404);exit;
                }
                $list_kabupaten = $wilayahService->search(['parent_kode_in' => [$children]]);
                return $list_kabupaten->toJson();
                break;

            case 3:
                // code...
                $list_kecamatan = $wilayahService->search(['parent_kode_in' => [$children]]);
                return $list_kecamatan->toJson();
                break;
            
            default:
                // code...
                abort(404);
                break;
        }
    }

    public function import_data(Request $request)
    {
        $provinsi_id = $request->input('provinsi_id') ?? '';
        if ($provinsi_id === '') return redirect()->back()->with('error', 'Pilih Provinsi');

        $wilayahService = new WilayahService();
        $provinsi = $wilayahService->find($provinsi_id);

        $indikatorService = new IndikatorService();
        $list_indikator = $indikatorService->search();
        $list_kabupaten = $wilayahService->search(['parent_kode' => $provinsi->kode]);
        $list_kecamatan = $wilayahService->search(['parent_kode_in' => $list_kabupaten->pluck('kode')->toArray()]);
        $pelaksanaService = new PelaksanaService();
        $list_pelaksana = $pelaksanaService->search();
        $kategoriPaketPekerjaanService = new KategoriPaketPekerjaanService();
        $list_kategori = $kategoriPaketPekerjaanService->search();
        $penyediaService = new PenyediaService();
        $list_penyedia = $penyediaService->search();

        session()->forget('list_error');
        Excel::import(new PaketPekerjaanImport($provinsi, $list_indikator, $list_kabupaten, $list_kecamatan, $list_pelaksana, $list_kategori, $list_penyedia), $request->file('file_excel'));

        $list_error = session('list_error', []);
        if (count($list_error) > 0) {
            return redirect()->back()->with('error', $list_error);
        }
        return redirect()->back();
    }
}
