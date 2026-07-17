## Summary

<!--
What does this PR do and why? A few bullet points is enough.
For a new method, name it and say what C++ API it wraps.
For a bug fix, describe what was wrong.
-->

## Test plan

- [ ] `bundle exec rake` passes locally
- [ ] New public methods have a YARD entry in `lib/pico_phone/phone_number.rb`
- [ ] Changes to `pico_phone.cpp` or the build system: run `PICO_PHONE_NATIVE_BUILD=1 bundle exec rake compile spec` as well
- [ ] C++ extension changes: run `bash verify_docker.sh` (requires Docker) before merging
