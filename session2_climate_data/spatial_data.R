library(sf)
library(terra)

# Province (ADM1) boundaries ----------------------------------------------
shape_file <- st_read(
  file.path(data_dir, "shape_files",
            "tha_admbnda_adm1_rtsd_20190221",
            "tha_admbnda_adm1_rtsd_20190221.shp"),
  quiet = TRUE
)
region_names <- shape_file$ADM1_EN

# Preview what we have loaded ---------------------------------------------
shape_file |>
  slice_head(n = 5)     # the first 5 rows as a clean table in quarto

glue::glue("Number of provinces in shapefile: {length(region_names)}")

missing <- setdiff(selected_provinces, region_names)
glue::glue("Provinces not matched in shapefile and dropped: {paste(missing, collapse = ", ")}")

selected_provinces <- intersect(selected_provinces, region_names)
glue::glue("Provinces carried forward (matched to boundaries): 
    {length(selected_provinces)}")

# One netCDF file per month; sorting the file paths puts them in time order.
tas_files <- sort(list.files(
  file.path(data_dir, "reanalysis", "monthly-averaged", "2t"),
  pattern = "\\.nc$", recursive = TRUE, full.names = TRUE))
pr_files <- sort(list.files(
  file.path(data_dir, "reanalysis", "monthly-averaged", "tp"),
  pattern = "\\.nc$", recursive = TRUE, full.names = TRUE))

tas_r <- rast(tas_files)   # temperature, one layer per month (Kelvin)
pr_r  <- rast(pr_files)    # total precipitation, one layer per month (metres)

# Restrict to the Thailand region 
region_ext <- ext(97, 108, 5, 22)
tas_r <- crop(tas_r, region_ext)
pr_r  <- crop(pr_r,  region_ext)

# Rainfall time base. ERA5 tp and CMIP flux are per-day rates; multiplying by the days
# in a month reports monthly totals. This ONE constant is the whole monthly-vs-daily
# switch: set it to 1 for daily rates. It is reused by the CMIP conversion in Part 4.
DAYS_PER_MONTH <- 30
pr_r  <- pr_r * DAYS_PER_MONTH   # tp: mean daily rate (m/day) -> monthly total (m/month)

# Recover the month for each layer from the filename (YYYYMMDD-...)
month_from_file <- function(f)
  floor_date(as.Date(sub(".*_(\\d{8})-\\d{8}\\.nc$", "\\1", basename(f)),
                     format = "%Y%m%d"), "month")
clim_months <- month_from_file(tas_files)
glue::glue("Reanalysis covers {length(clim_months)} months: 
    {format(min(clim_months))} to {format(max(clim_months))}")

# Map of the time-mean temperature and rainfall over the region -----------
tas_mean_c <- mean(tas_r) - 273.15          # Kelvin -> Celsius for display
pr_mean    <- mean(pr_r)

map_df_t <- as.data.frame(tas_mean_c, xy = TRUE) |>
  rename(value = last_col())
map_df_r <- as.data.frame(pr_mean, xy = TRUE) |>
  rename(value = last_col())

m_t <- ggplot(map_df_t, aes(x, y, fill = value)) +
  geom_raster() +
  geom_sf(data = shape_file, fill = NA, colour = "grey30",
          linewidth = 0.2, inherit.aes = FALSE) +
  scale_fill_steps2(low = "#2166ac", mid = "white", high = "#b2182b",
                    midpoint = 25, limits = c(20, 30), breaks = seq(20, 30, 1),
                    name = "°C", oob = scales::squish) +
  coord_sf(expand = FALSE) +
  labs(title = "Mean temperature", x = "lon", y = "lat") +
  theme_bw()

m_r <- ggplot(map_df_r, aes(x, y, fill = value)) +
  geom_raster() +
  geom_sf(data = shape_file, fill = NA, colour = "grey30",
          linewidth = 0.2, inherit.aes = FALSE) +
  scale_fill_viridis_b(name = "m/month", option = "mako", n.breaks = 8) +
  coord_sf(expand = FALSE) +
  labs(title = "Mean rainfall", x = "lon", y = "lat") +
  theme_bw()

m_t + m_r



# Assign each grid cell to the province whose polygon contains its *centre*.
grid_xy  <- terra::xyFromCell(tas_r, seq_len(terra::ncell(tas_r)))
grid_pts <- sf::st_as_sf(as.data.frame(grid_xy), coords = c("x", "y"),
                         crs = sf::st_crs(shape_file))
within   <- sf::st_within(grid_pts, shape_file)          # cell centre in polygon?
cell_region <- vapply(within,
                      function(h) if (length(h)) h[1] else NA_integer_,
                      integer(1))

# Check 1: colour each grid cell by the province it landed in.
assign_df <- tibble::tibble(
  x = grid_xy[, 1],
  y = grid_xy[, 2],
  province_id = cell_region
)
p_assign <- assign_df |>
  filter(!is.na(province_id)) |>
  ggplot(aes(x, y, fill = province_id)) +
  geom_raster() +
  geom_sf(data = shape_file, fill = NA, colour = "grey20",
          linewidth = 0.2, inherit.aes = FALSE) +
  scale_fill_viridis_c(guide = "none") +
  coord_sf(expand = FALSE) +
  labs(title = "Grid cells coloured by assigned province", x = "lon", y = "lat") +
  theme_bw()

# Check 2: which provinces are carried into the model (selected in Part 2)?
modelled_sf <- shape_file |>
  mutate(
    modelled = if_else(
      ADM1_EN %in% selected_provinces,
      "modelled",
      "not modelled"
    )
  )
p_modelled <- ggplot(modelled_sf) +
  geom_sf(aes(fill = modelled), colour = "grey40", linewidth = 0.2) +
  scale_fill_manual(values = c("modelled" = "#08519c", "not modelled" = "grey88"),
                    name = NULL) +
  coord_sf(expand = FALSE) +
  labs(title = "Provinces carried into the model", x = "lon", y = "lat") +
  theme_bw()

p_assign | p_modelled   # side by side (patchwork)

# Provincial means, area-weighted by cos(latitude); see technical note.
# The assignment and weights are reused for the CMIP data in Part 4.
cell_w <- cos(grid_xy[, 2] * pi / 180)                    # per-cell area weight (cos latitude)
region_means <- function(r) {
  vals <- terra::values(r)                                # ncell x nlayer
  out  <- matrix(NA_real_, length(region_names), ncol(vals),
                 dimnames = list(region_names, NULL))
  for (k in seq_along(region_names)) {
    sel <- which(cell_region == k)
    if (!length(sel)) next
    w    <- cell_w[sel]
    vsel <- vals[sel, , drop = FALSE]
    # Weighted mean over the NON-NA cells: normalise by the weights actually used, so a
    # layer that is all NA gives NA (not 0). Matches xarray's weighted().mean(skipna);
    # it matters for CMIP, where some models are missing (NA) in the final months.
    out[k, ] <- colSums(vsel * w, na.rm = TRUE) / colSums((!is.na(vsel)) * w)
  }
  out
}

tas_prov <- region_means(tas_r)
pr_prov  <- region_means(pr_r)

# Tidy into long tables, keeping only the selected provinces
to_long <- function(mat, value_name) {
  m <- as.matrix(mat)
  rownames(m) <- region_names
  colnames(m) <- as.character(clim_months)
  as.data.frame(m) |>
    tibble::rownames_to_column("province_en") |>
    pivot_longer(-province_en, names_to = "month", values_to = value_name) |>
    mutate(month = as.Date(month))
}

clim_long <- to_long(tas_prov, "temp_k") |>
  left_join(to_long(pr_prov, "rain_m"), by = c("province_en", "month")) |>
  mutate(temp_c = temp_k - 273.15) |>
  filter(province_en %in% selected_provinces)

clim_long |>
  slice_head(n = 6)


ggplot(clim_long, aes(month, temp_c)) +
  geom_line() + geom_point(size = 0.5) +
  facet_wrap(~ province_en, scales = "free_y") +
  labs(x = "date", y = "monthly mean temperature (°C)") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

ggplot(clim_long, aes(month, rain_m)) +
  geom_line() + geom_point(size = 0.5) +
  facet_wrap(~ province_en, scales = "free_y") +
  labs(x = "date", y = "monthly rainfall (m/month)") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))
