.PHONY: build verify clean package icons

build:
	/bin/zsh Scripts/build.sh

verify:
	/bin/zsh Scripts/verify.sh

clean:
	/bin/zsh Scripts/clean.sh

package:
	/bin/zsh Scripts/package-release.sh

icons:
	/bin/zsh Scripts/update-icon.sh
