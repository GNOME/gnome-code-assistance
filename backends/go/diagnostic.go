package main

type Severity uint32

const (
	SeverityNone Severity = iota
	SeverityInfo
	SeverityWarning
	SeverityDeprecated
	SeverityError
	SeverityFatal
)

type Fixit struct {
	Location    SourceRange
	Replacement string
}

type Diagnostic struct {
	Severity  Severity
	Fixits    []Fixit
	Locations []SourceRange
	Message   string
}

func (d *Document) Diagnostics() []Diagnostic {
	d.mutex.Lock()
	defer d.mutex.Unlock()

	if d.parsed == nil || d.parsed.Errors == nil {
		return []Diagnostic{}
	}

	ret := make([]Diagnostic, len(d.parsed.Errors))

	for i, err := range d.parsed.Errors {
		ret[i] = Diagnostic{
			Severity: SeverityError,
			Locations: []SourceRange{
				SourceRange{
					Start: SourceLocation{
						Line:   int64(err.Pos.Line),
						Column: int64(err.Pos.Column),
					},
					End: SourceLocation{
						Line:   int64(err.Pos.Line),
						Column: int64(err.Pos.Column),
					},
				},
			},
			Message: err.Msg,
			Fixits:  []Fixit{},
		}
	}

	return ret
}
