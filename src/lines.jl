# The lines of an SMPS file, and the digits of its numbers.

const SECTIONS = ("NAME", "OBJSENSE", "ROWS", "COLUMNS", "RHS", "RANGES", "BOUNDS", "ENDATA",
                  "TIME", "PERIODS", "STOCH", "INDEP", "BLOCKS", "SCENARIOS", "SCEN")

"""The fields of the meaningful lines of an SMPS file, each with whether it is a section header:
no comments (an asterisk first), no blank lines. A header starts in the first column, or is a
lone keyword indented by mistake (as in SPLIB's stocfor1)."""
function smps_lines(path::AbstractString)
    lines = Tuple{Bool,Vector{String}}[]
    for line in eachline(path)
        stripped = strip(line)
        (isempty(stripped) || startswith(stripped, '*')) && continue
        fields = String.(split(stripped))
        header = !isspace(line[1]) || (length(fields) <= 2 && uppercase(fields[1]) in SECTIONS)
        push!(lines, (header, fields))
    end
    return lines
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
