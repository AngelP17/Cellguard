package agent

import "context"

type Agent interface {
	Name() string
	Run(ctx context.Context) error
}
