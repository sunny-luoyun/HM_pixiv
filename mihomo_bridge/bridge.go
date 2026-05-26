package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
	"sync"
	"unsafe"

	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/log"
	"gopkg.in/yaml.v3"
)

var (
	mu      sync.Mutex
	running bool
)

type ProxyConfig struct {
	Name      string            `yaml:"name"`
	Type      string            `yaml:"type"`
	Server    string            `yaml:"server"`
	Port      int               `yaml:"port"`
	Cipher    string            `yaml:"cipher"`
	Password  string            `yaml:"password"`
	Plugin    string            `yaml:"plugin,omitempty"`
	PluginOpts map[string]string `yaml:"plugin-opts,omitempty"`
}

type ProxyGroup struct {
	Name    string   `yaml:"name"`
	Type    string   `yaml:"type"`
	Proxies []string `yaml:"proxies"`
	URL     string   `yaml:"url,omitempty"`
	Interval int     `yaml:"interval,omitempty"`
}

type ClashConfig struct {
	MixedPort int          `yaml:"mixed-port"`
	Mode      string       `yaml:"mode"`
	LogLevel  string       `yaml:"log-level"`
	AllowLan  bool         `yaml:"allow-lan"`
	Proxies   []ProxyConfig `yaml:"proxies"`
	Groups    []ProxyGroup `yaml:"proxy-groups"`
	Rules     []string     `yaml:"rules"`
}

//export StartProxy
func StartProxy(configPath *C.char) *C.char {
	path := C.GoString(configPath)
	mu.Lock()
	defer mu.Unlock()
	if running {
		return makeJSON(false, "proxy already running")
	}

	log.SetLevel(log.INFO)
	cfg, err := executor.ParseWithPath(path)
	if err != nil {
		return makeJSON(false, "parse config failed: "+err.Error())
	}
	executor.ApplyConfig(cfg, true)
	running = true
	return makeJSON(true, "proxy started")
}

//export StopProxy
func StopProxy() *C.char {
	mu.Lock()
	defer mu.Unlock()
	if !running {
		return makeJSON(false, "proxy not running")
	}
	executor.Shutdown()
	running = false
	return makeJSON(true, "proxy stopped")
}

//export GetStatus
func GetStatus() *C.char {
	mu.Lock()
	r := running
	mu.Unlock()
	resp := map[string]any{"success": true, "running": r}
	b, _ := json.Marshal(resp)
	return C.CString(string(b))
}

//export PrepareConfig
func PrepareConfig(subscriptionUrl *C.char, rawContent *C.char) *C.char {
	raw := C.GoString(rawContent)

	decoded := tryBase64Decode(raw)
	content := decoded
	if content == "" {
		content = raw
	}

	trimmed := strings.TrimSpace(content)
	if strings.Contains(trimmed, "proxies:") || strings.Contains(trimmed, "proxy-groups:") {
		result := map[string]any{"success": true, "config": content}
		b, _ := json.Marshal(result)
		return C.CString(string(b))
	}

	lines := strings.Split(trimmed, "\n")
	var proxies []ProxyConfig
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "ss://") {
			if p := parseSS(line); p != nil {
				proxies = append(proxies, *p)
			}
		}
	}

	if len(proxies) == 0 {
		result := map[string]any{"success": false, "error": "no valid proxy urls found"}
		b, _ := json.Marshal(result)
		return C.CString(string(b))
	}

	var names []string
	for _, p := range proxies {
		names = append(names, p.Name)
	}

	cfg := ClashConfig{
		MixedPort: 7890,
		Mode:      "Rule",
		LogLevel:  "info",
		AllowLan:  false,
		Proxies:   proxies,
		Groups: []ProxyGroup{
			{
				Name:    "Auto",
				Type:    "url-test",
				Proxies: names,
				URL:     "http://www.gstatic.com/generate_204",
				Interval: 300,
			},
		},
		Rules: []string{"MATCH,Auto"},
	}

	yamlBytes, err := yaml.Marshal(&cfg)
	if err != nil {
		result := map[string]any{"success": false, "error": fmt.Sprintf("yaml marshal: %v", err)}
		b, _ := json.Marshal(result)
		return C.CString(string(b))
	}

	result := map[string]any{"success": true, "config": string(yamlBytes)}
	b, _ := json.Marshal(result)
	return C.CString(string(b))
}

func parseSS(rawURL string) *ProxyConfig {
	s := strings.TrimPrefix(rawURL, "ss://")

	remark := ""
	if idx := strings.LastIndex(s, "#"); idx >= 0 {
		remark, _ = url.QueryUnescape(s[idx+1:])
		s = s[:idx]
	}

	atIdx := strings.Index(s, "@")
	if atIdx < 0 {
		return nil
	}
	b64Part := s[:atIdx]
	serverPart := s[atIdx+1:]

	decoded, err := base64.URLEncoding.WithPadding(base64.NoPadding).DecodeString(b64Part)
	if err != nil {
		decoded, err = base64.StdEncoding.DecodeString(b64Part)
		if err != nil {
			return nil
		}
	}

	cred := string(decoded)
	colonIdx := strings.Index(cred, ":")
	if colonIdx < 0 {
		return nil
	}
	method := cred[:colonIdx]
	password := cred[colonIdx+1:]

	hostPort := serverPart
	var plugin string
	var pluginOpts map[string]string

	if qIdx := strings.Index(serverPart, "?"); qIdx >= 0 {
		hostPort = strings.TrimRight(serverPart[:qIdx], "/")
		if parsedQuery, err := url.ParseQuery(serverPart[qIdx+1:]); err == nil {
			if p := parsedQuery.Get("plugin"); p != "" {
				parts := strings.SplitN(p, ";", 2)
				plugin = parts[0]
				switch plugin {
				case "simple-obfs":
					plugin = "obfs"
				}
				if len(parts) > 1 {
					pluginOpts = make(map[string]string)
					for _, opt := range strings.Split(parts[1], ";") {
						if kv := strings.SplitN(opt, "=", 2); len(kv) == 2 {
							switch kv[0] {
							case "obfs":
								pluginOpts["mode"] = kv[1]
							case "obfs-host":
								pluginOpts["host"] = kv[1]
							default:
								pluginOpts[kv[0]] = kv[1]
							}
						}
					}
				}
			}
		}
	}

	host := hostPort
	port := 0
	if colonIdx := strings.LastIndex(hostPort, ":"); colonIdx >= 0 {
		host = hostPort[:colonIdx]
		fmt.Sscanf(hostPort[colonIdx+1:], "%d", &port)
	}

	name := remark
	if name == "" {
		name = fmt.Sprintf("%s:%d", host, port)
	}

	p := &ProxyConfig{
		Name:     name,
		Type:     "ss",
		Server:   host,
		Port:     port,
		Cipher:   method,
		Password: password,
	}
	if plugin != "" {
		p.Plugin = plugin
		p.PluginOpts = pluginOpts
	}
	return p
}

func tryBase64Decode(s string) string {
	cleaned := strings.Map(func(r rune) rune {
		if r == '\n' || r == '\r' || r == ' ' || r == '\t' {
			return -1
		}
		return r
	}, strings.TrimSpace(s))

	if len(cleaned) < 20 || len(cleaned)%4 != 0 {
		return ""
	}

	decoded, err := base64.StdEncoding.DecodeString(cleaned)
	if err != nil {
		decoded, err = base64.RawStdEncoding.DecodeString(cleaned)
		if err != nil {
			return ""
		}
	}
	return string(decoded)
}

//export FreeString
func FreeString(s *C.char) {
	C.free(unsafe.Pointer(s))
}

func makeJSON(success bool, msg string) *C.char {
	resp := map[string]any{"success": success, "message": msg}
	b, _ := json.Marshal(resp)
	return C.CString(string(b))
}

func main() {}
