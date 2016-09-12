---
layout: page
title: Projects
permalink: /projects/
---

{% for project in site.data.projects %}
## [{{ project.name }}]({{ project.link }})
{{ project.description }}
{% endfor %}

<hr />

