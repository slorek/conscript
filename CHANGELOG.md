## v0.2.1

* Fixed bug where associated `has_many` records with CarrierWave uploads were not duplicated correctly - uploaded files are now copied
* Fixed bug where destroying a draft would remove an uploaded file from its draft parent if they shared the same file.
* Fixed bug where drafts were destroyed before publish_Draft was successful
* Added an ActiveRecord error where `save` fails if drafts exist for an instance

## v0.2.0

* Now defines a `published` scope rather than a `default_scope`. This avoids a number of complexities especially around validations and polymorphic relationships.

## v0.1.1

* CarrierWave uplaods on associated records are now cloned correctly.

## v0.1.0

* Additional callbacks added to allow bespoke behaviour around the save as draft and publish draft lifecycles.
* Additional options added to remove previously documented limitations.

## v0.0.1

* First release.