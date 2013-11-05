package main

import (
	"fmt"
	"reflect"
)

type Options struct {
	GoPath           string
	BuildConstraints []string
}

func (o *Options) Parse(options map[string]interface{}) error {
	v := reflect.Indirect(reflect.ValueOf(o))
	t := v.Type()

	fields := make(map[string]reflect.Value)

	for i := 0; i < t.NumField(); i++ {
		field := t.Field(i)
		fields[field.Name] = v.Field(i)
	}

	var err error

	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("%v", r)
		}
	}()

	for k, v := range options {
		if val, ok := fields[k]; ok {
			val.Set(reflect.ValueOf(v))
		} else {
			err = fmt.Errorf("Invalid option %s", k)
			break
		}
	}

	return err
}
