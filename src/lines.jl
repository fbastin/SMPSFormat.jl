# The lines of an SMPS file, and the digits of its numbers.

const SECTIONS = ("NAME", "OBJSENSE", "OBJNAME", "ROWS", "COLUMNS", "RHS", "RANGES", "BOUNDS", "ENDATA",
                  "TIME", "PERIODS", "STOCH", "INDEP", "BLOCKS", "SCENARIOS", "SCEN")

"""The meaningful lines of an SMPS file, as `(header, fields, number)`: whether the line is a
section header, its fields, its number in the file. No comments (an asterisk first, or a hash in
the first column, as CoinMpsIO reads them), no blank lines. A header starts in the first column,
or is a lone keyword indented by mistake (as in SPLIB's stocfor1). A file whose name ends in
`.gz` is read through gzip.

In free format, the fields are separated by blanks. In fixed format (`format = :fixed`), the
fields of a data line lie in the columns of MPS, 2–3, 5–12, 15–22, 25–36, 40–47 and 50–61, so
that a name may contain blanks: a word belongs to the field it starts in, or to the next one if
it starts between two (SMI writes the period of an `SC` line in column 39), the words of a field
form one name, and what starts after column 61 is ignored; the fields left empty are dropped, as
in free format."""
function smps_lines(path::AbstractString; format::Symbol = :free)
    format in (:free, :fixed) || error("format must be :free or :fixed, got :$format")
    lines = Tuple{Bool,Vector{String},Int}[]
    io = endswith(lowercase(path), ".gz") ? GzipDecompressorStream(open(path)) : open(path)
    try
        for (number, line) in enumerate(eachline(io))
            stripped = strip(line)
            (isempty(stripped) || startswith(stripped, '*') || line[1] == '#') && continue
            fields = String.(split(stripped))
            header = !isspace(line[1]) || (length(fields) <= 2 && uppercase(fields[1]) in SECTIONS)
            if !header && format === :fixed
                fields = fixed_fields(line)
            end
            push!(lines, (header, fields, number))
        end
    finally
        close(io)
    end
    return lines
end

const FIXED_FIELDS = ((2, 3), (5, 12), (15, 22), (25, 36), (40, 47), (50, 61))

"""The fields of a data line in fixed MPS format (see [`smps_lines`](@ref))."""
function fixed_fields(line::AbstractString)
    chars = collect(replace(line, '\t' => "        "))
    fields = [Int[] for _ in FIXED_FIELDS]           # the columns of the words of each field
    k = 1
    while k <= length(chars)
        isspace(chars[k]) && (k += 1; continue)
        stop = k
        while stop < length(chars) && !isspace(chars[stop+1])
            stop += 1
        end
        f = findfirst(((a, b),) -> k <= b, FIXED_FIELDS)  # its field, or the next one
        f === nothing && break                       # after column 61: ignored
        push!(fields[f], k, stop)
        k = stop + 1
    end
    return [String(chars[first(c):last(c)]) for c in fields if !isempty(c)]
end

"""The half unit of the last digit written in the number `s`: 0.000005 for `"0.16667"`, 0.0005
for `"0.038"`, 0.5 for `"1"`; the rounding a number may carry, as written."""
function half_unit(s::AbstractString)
    m = match(r"^[+-]?(\d*)(?:\.(\d*))?(?:[eEdD]([+-]?\d+))?$", s)
    m === nothing && return 0.0
    decimals = m.captures[2] === nothing ? 0 : length(m.captures[2])
    exponent = m.captures[3] === nothing ? 0 : parse(Int, m.captures[3])
    return 0.5 * 10.0^(exponent - decimals)
end

"""A number of an SMPS file: Fortran's `D` exponent is read as `E`."""
number(s::AbstractString) = parse(Float64, replace(s, r"[dD]" => "e"))
