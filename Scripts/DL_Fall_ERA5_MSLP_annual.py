import cdsapi
import sys

c = cdsapi.Client()



c.retrieve(
    'reanalysis-era5-single-levels-monthly-means',
    {
        'format': 'grib',
        'product_type': 'monthly_averaged_reanalysis',
        'variable': 'mean_sea_level_pressure',
        'year': str(sys.argv[1]),
        'month': ['09', '10', '11'],
        'time': '00:00',
    },str(sys.argv[2]) + '/fall_era5_download.grib')
