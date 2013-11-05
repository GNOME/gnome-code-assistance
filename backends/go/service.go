package main

type Service struct {
}

func NewService() *Service {
	return &Service{}
}

func (s *Service) Parse(path string, cursor int64, unsaved []UnsavedDocument, options Options, doc *Document) (*Document, error) {
	parsed, err := TheParser.Parse(path, cursor, unsaved, options)

	if err != nil {
		return doc, err
	}

	if doc == nil {
		doc = NewDocument(path)
	}

	doc.parsed = parsed
	return doc, nil
}

func (s *Service) Dispose(doc *Document) error {
	return nil
}
