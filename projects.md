---
layout: page
title: Projects
---

{% for project in site.data.projects %}
## [{{ project.name }}]({{ project.link }})
{{ project.description }}
{% endfor %}
