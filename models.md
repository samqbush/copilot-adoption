---
layout: default
title: Models
description: This matrix provides a curated list of available GitHub Copilot models and their GA dates
---

<style>
  /* Table container to allow wider table than parent container */
  .table-container {
    width: 100%;
    max-width: 100%;
    overflow-x: auto;
    margin-bottom: 1rem;
  }
  
  .sortable {
    border-collapse: collapse;
    width: 100%;
    min-width: 1100px; /* Ensures table has a minimum width */
    table-layout: fixed; /* Ensures consistent column widths */
  }
  .sortable th, .sortable td {
    padding: 12px; /* Increased padding for better spacing */
    text-align: left;
    border: 1px solid #ddd; /* Added border for better separation */
    overflow-wrap: break-word;
    word-wrap: break-word;
    hyphens: auto;
  }
  .sortable th {
    cursor: pointer;
    background-color: #f9f9f9; /* Lighter background for headers */
    position: sticky; /* Keeps headers visible when scrolling */
    top: 0;
    z-index: 1;
    text-align: left; /* Ensures proper alignment */
    padding-right: 25px; /* Add space for sort icon */
    position: relative; /* For positioning the icon */
  }
  .sortable th:hover {
    background-color: #e2e2e2;
    color: #0078d4; /* Highlight color for better visibility */
  }
  
  /* Add clear sort icons that indicate sortability */
  .sortable th::after {
    content: "↕";
    position: absolute;
    right: 8px;
    color: #999;
    font-size: 0.85em;
  }
  
  /* Change icon based on sort state */
  .sortable th.asc::after {
    content: "↑";
    color: #0078d4;
  }
  .sortable th.desc::after {
    content: "↓";
    color: #0078d4;
  }
  
  /* Additional visual cue on hover */
  .sortable th:hover::after {
    color: #0078d4;
  }
  
  .sortable td {
    white-space: normal;
  }
  
  /* Adjusted column widths */
  .sortable th:nth-child(1), .sortable td:nth-child(1) { width: 18%; }  /* Model */
  .sortable th:nth-child(2), .sortable td:nth-child(2) { width: 14%; }  /* Release Stage */
  .sortable th:nth-child(3), .sortable td:nth-child(3) { width: 10%; }  /* GA Date */
  
  /* Special handling for GA Date column */
  .sortable td:nth-child(3), .sortable th:nth-child(3) {
    text-align: center; /* Center-align dates for better readability */
  }
  
  .sortable tr:hover {
    background-color: #f1f1f1; /* Subtle hover effect for rows */
  }
  
  /* For better link display */
  .sortable td a {
    word-break: break-word;
    color: #0078d4; /* Consistent link color */
    text-decoration: none;
  }
  .sortable td a:hover {
    text-decoration: underline;
  }

  /* Add a note above the table about sorting */
  .sort-note {
    margin-bottom: 10px;
    font-style: italic;
    color: #555;
  }
  
  /* Make page container wider if theme supports it */
  .main-content {
    max-width: 96% !important;
  }
  
  /* Media query for responsive behavior */
  @media screen and (max-width: 1200px) {
    .table-container {
      overflow-x: scroll;
    }
  }
</style>

<p class="sort-note">Click on any column header to sort the table. Click again to reverse the sort order.</p>

<div class="table-container">
<table id="featureTable" class="sortable">
  <thead>
    <tr>
      <th>Model</th>
      <th>Release Stage</th>
      <th>GA Date</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Claude Sonnet 3.5</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-04-04-multiple-new-models-are-now-generally-available-in-github-copilot/">April 4, 2025</a></td>
    </tr>
    <tr>
      <td>Claude Sonnet 3.7</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-04-04-multiple-new-models-are-now-generally-available-in-github-copilot/">April 4, 2025</a></td>
    </tr>
    <tr>
      <td>Claude Sonnet 3.7 Thinking</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-04-04-multiple-new-models-are-now-generally-available-in-github-copilot/">April 4, 2025</a></td>
    </tr>
    <tr>
      <td>o3-mini</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-04-04-multiple-new-models-are-now-generally-available-in-github-copilot/">April 4, 2025</a></td>
    </tr>
    <tr>
      <td>o3</td>
      <td>Public Preview</td>
      <td><a href="https://github.blog/changelog/2025-04-16-openai-o3-and-o4-mini-are-now-available-in-public-preview-for-github-copilot-and-github-models/">TBD</a></td>
    </tr>
    <tr>
      <td>o4-mini</td>
      <td>Public Preview</td>
      <td><a href="https://github.blog/changelog/2025-04-16-openai-o3-and-o4-mini-are-now-available-in-public-preview-for-github-copilot-and-github-models/">TBD</a></td>
    </tr>
    <tr>
      <td>Gemini Flash 2.0</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-04-04-multiple-new-models-are-now-generally-available-in-github-copilot/">April 4, 2025</a></td>
    </tr>
    <tr>
      <td>GPT-4.1</td>
      <td>Public Preview</td>
      <td><a href="https://github.blog/changelog/2025-04-14-openai-gpt-4-1-now-available-in-public-preview-for-github-copilot-and-github-models/">TBD</a></td>
    </tr>
    <tr>
      <td>GPT-4.5</td>
      <td>Public Preview</td>
      <td><a href="https://github.blog/changelog/2025-02-27-openai-gpt-4-5-in-github-copilot-now-available-in-public-preview/">TBD</a></td>
    </tr>
  </tbody>
</table>
</div>

<script>
document.addEventListener('DOMContentLoaded', function() {
  // Get the table element
  const table = document.getElementById('featureTable');
  const headers = table.querySelectorAll('th');
  const tableBody = table.querySelector('tbody');
  const rows = Array.from(tableBody.querySelectorAll('tr'));
  
  // Direction tracking variables
  let currentColumn = -1;
  let currentDirection = 'asc';
  
  // Function to clean and transform cell content for sorting
  function getCellValue(row, index) {
    const cell = row.querySelector(`td:nth-child(${index + 1})`);
    let text = cell.textContent.trim().toLowerCase();
    
    // Handle date sorting
    if (index === 3) { // GA Date column
      if (text === 'tbd' || text === '') return Infinity; // Put TBD at the end
      
      // Look for dates like "October 2024" or "March 21, 2024"
      if (text.match(/\b(january|february|march|april|may|june|july|august|september|october|november|december)/i)) {
        const dateObj = new Date(text);
        if (!isNaN(dateObj)) return dateObj.getTime();
      }
      
      // Look for year
      const yearMatch = text.match(/\b(20\d{2})\b/);
      if (yearMatch) return new Date(yearMatch[0], 0, 1).getTime();
    }
    
    // Try numeric conversion if appropriate
    if (!isNaN(text) && text !== '') {
      return Number(text);
    }
    
    return text;
  }

  // Function for comparing values
  function compareValues(v1, v2) {
    return v1 === v2 ? 0 : 
           v1 === Infinity ? 1 : 
           v2 === Infinity ? -1 : 
           v1 > v2 ? 1 : -1;
  }

  // Sort function
  function sortTable(index, direction) {
    // Remove classes from all headers
    headers.forEach(header => {
      header.classList.remove('asc', 'desc');
    });
    
    // Add class to the current header
    headers[index].classList.add(direction);
    
    // Sort the rows
    const sortedRows = rows.sort((a, b) => {
      const aValue = getCellValue(a, index);
      const bValue = getCellValue(b, index);
      
      return direction === 'asc' ? 
        compareValues(aValue, bValue) : 
        compareValues(bValue, aValue);
    });
    
    // Remove all rows from the table
    while (tableBody.firstChild) {
      tableBody.removeChild(tableBody.firstChild);
    }
    
    // Re-add rows in the sorted order
    sortedRows.forEach(row => {
      tableBody.appendChild(row);
    });
    
    // Update tracking variables
    currentColumn = index;
    currentDirection = direction;
  }

  // Add click event to each header
  headers.forEach((header, index) => {
    header.addEventListener('click', function() {
      // Determine sorting direction
      const direction = index === currentColumn && currentDirection === 'asc' ? 'desc' : 'asc';
      sortTable(index, direction);
    });
    
    // Add tabindex for accessibility
    header.setAttribute('tabindex', '0');
    
    // Add keyboard support
    header.addEventListener('keydown', function(e) {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        header.click();
      }
    });
  });
});
</script>

<br>
<br>

Additional Info
- [Model Recommendations](https://github.blog/ai-and-ml/github-copilot/which-ai-model-should-i-use-with-github-copilot/)
- [Model Comparisons with LLM Leaderboard](https://www.vellum.ai/llm-leaderboard)