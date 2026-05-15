module DataLoader

using Downloads
using CSV
using DataFrames

export load_returns, ensure_data

const ZIP_URL = "https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/ftp/30_Industry_Portfolios_CSV.zip"
const DATA_DIR = joinpath(@__DIR__, "..", "data")
const CSV_PATH = joinpath(DATA_DIR, "30_Industry_Portfolios.csv")

function ensure_data()
    isfile(CSV_PATH) && return CSV_PATH
    mkpath(DATA_DIR)
    zip_path = joinpath(DATA_DIR, "30_Industry_Portfolios.zip")
    @info "Downloading Fama-French 30 Industry Portfolios..."
    Downloads.download(ZIP_URL, zip_path)
    run(`unzip -o $zip_path -d $DATA_DIR`)
    local csv_file = nothing
    for f in readdir(DATA_DIR)
        if endswith(f, r"\.(csv|CSV)") && occursin(r"30.*(Portfolio|Industry)", f)
            csv_file = f
            break
        end
    end
    if csv_file === nothing
        error("Could not find extracted CSV in $DATA_DIR")
    end
    final_path = joinpath(DATA_DIR, csv_file)
    final_path != CSV_PATH && mv(final_path, CSV_PATH, force=true)
    return CSV_PATH
end

function strip_french_csv(filepath)
    lines = readlines(filepath)
    data_start = nothing
    data_end = nothing

    for (i, line) in enumerate(lines)
        stripped = strip(line)
        if occursin(r"^\d{6}", stripped)
            data_start === nothing && (data_start = i)
        elseif data_start !== nothing
            data_end = i - 1
            break
        end
    end
    data_end === nothing && (data_end = length(lines))
    @info "Parsing rows $data_start to $data_end ($(data_end - data_start + 1) months)"

    df = CSV.read(filepath, DataFrame, skipto=data_start, header=false,
                  limit=data_end - data_start + 1)
    ncols = size(df, 2)
    # Drop columns that are all missing, keep data columns (col 2 to min(31,ncols))
    ret_end = min(31, ncols)
    R_raw = Matrix{Float64}(df[:, 2:ret_end]) ./ 100.0
    # Remove rows where any return is -99.99 (missing data sentinel), -999, or NaN
    bad = vec(any(x -> (x < -0.5) || isnan(x), R_raw, dims=2))
    R = R_raw[.!bad, :]
    @info "Loaded returns: $(size(R,1)) months × $(size(R,2)) industries (dropped $(sum(bad)) invalid rows)"
    return R
end

function load_returns()
    csv_path = ensure_data()
    R = strip_french_csv(csv_path)
    n, d = size(R)
    p = fill(1.0 / n, n)
    L = -R
    return R, L, p, n, d
end

end
