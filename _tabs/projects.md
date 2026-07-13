---
layout: page
title: Proyectos
icon: fas fa-code
order: 3
---

Aquí comparto algunos de mis proyectos de desarrollo y herramientas de seguridad enfocadas principalmente en el ecosistema de Java y Spring Boot.

<style>
  .project-card {
    transition: transform 0.2s ease-in-out, box-shadow 0.2s ease-in-out;
    background-color: var(--card-bg) !important;
    border: 1px solid var(--main-border-color) !important;
    border-radius: 8px;
  }
  .project-card:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 20px rgba(0, 0, 0, 0.15) !important;
  }
  .project-tag {
    font-size: 0.75rem;
    padding: 0.2rem 0.5rem;
    border-radius: 4px;
    background-color: var(--tag-bg) !important;
    color: var(--tag-color) !important;
    border: 1px solid var(--main-border-color);
    margin-right: 0.25rem;
    margin-bottom: 0.25rem;
    display: inline-block;
    text-decoration: none !important;
  }
  .project-btn {
    font-size: 0.85rem !important;
    padding: 0.375rem 0.75rem !important;
    border-radius: 6px !important;
    font-weight: 500 !important;
  }
</style>

<div class="row row-cols-1 row-cols-md-2 g-4 mt-3">
  {% for project in site.data.projects %}
  <div class="col">
    <div class="card h-100 project-card">
      <div class="card-body d-flex flex-column p-4">
        <h5 class="card-title fw-bold text-primary mb-2">{{ project.name }}</h5>
        <p class="card-text text-muted flex-grow-1" style="font-size: 0.9rem; line-height: 1.6;">
          {{ project.description }}
        </p>
        <div class="mt-3 mb-3">
          {% for tag in project.tags %}
          <span class="project-tag">{{ tag }}</span>
          {% endfor %}
        </div>
        <div class="mt-auto d-flex justify-content-between align-items-center pt-2">
          {% if project.github %}
          <a href="{{ project.github }}" target="_blank" rel="noopener" class="btn btn-outline-primary btn-sm project-btn">
            <i class="fab fa-github me-1"></i> Código
          </a>
          {% endif %}
          {% if project.demo %}
          <a href="{{ project.demo }}" target="_blank" rel="noopener" class="btn btn-primary btn-sm project-btn">
            <i class="fas fa-external-link-alt me-1"></i> Demo
          </a>
          {% endif %}
        </div>
      </div>
    </div>
  </div>
  {% endfor %}
</div>
