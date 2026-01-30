#!/usr/bin/env node

/**
 * 技术博客文章生成器
 * 用于自动生成包含Java、Rust、AI等技术主题的文章
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// 技术主题配置
const TECH_TOPICS = {
  java: {
    title: 'Java技术深度解析',
    tags: ['java', 'jvm', 'spring', '微服务'],
    categories: [
      'JVM性能调优与内存管理',
      'Spring Boot高级特性',
      'Java并发编程实践',
      '微服务架构设计',
      'Java新特性解读'
    ]
  },
  rust: {
    title: 'Rust系统编程',
    tags: ['rust', '系统编程', '内存安全', '性能优化'],
    categories: [
      'Rust所有权模型深度解析',
      '异步编程与Tokio',
      'WebAssembly与Rust',
      '系统级编程实践',
      'Rust性能优化技巧'
    ]
  },
  ai: {
    title: '人工智能与机器学习',
    tags: ['ai', 'machine-learning', 'deep-learning', 'llm'],
    categories: [
      '大语言模型原理与实践',
      '深度学习框架对比',
      'AI工程化部署',
      '机器学习算法优化',
      'AIGC应用开发'
    ]
  },
  database: {
    title: '数据库技术',
    tags: ['database', 'mysql', 'postgresql', 'redis'],
    categories: [
      'MySQL性能优化实战',
      'PostgreSQL高级特性',
      'Redis分布式缓存',
      '数据库架构设计',
      'NewSQL技术趋势'
    ]
  },
  devops: {
    title: 'DevOps与云原生',
    tags: ['devops', 'kubernetes', 'docker', 'ci-cd'],
    categories: [
      'Kubernetes集群管理',
      'Docker容器化实践',
      'CI/CD流水线建设',
      '云原生架构设计',
      '监控与日志系统'
    ]
  }
};

// 文章内容模板
const ARTICLE_TEMPLATES = {
  tutorial: {
    title: '{topic} - 实战教程',
    structure: [
      '## 前言\n\n介绍{topic}的背景和重要性',
      '## 环境准备\n\n- 开发环境配置\n- 依赖项安装\n- 项目初始化',
      '## 核心概念\n\n详细解释{topic}的核心概念和原理',
      '## 实践案例\n\n通过具体例子演示{topic}的使用方法',
      '## 性能优化\n\n- 性能瓶颈分析\n- 优化策略\n- 最佳实践',
      '## 总结\n\n总结{topic}的关键要点和学习心得'
    ]
  },
  comparison: {
    title: '{topic} - 技术对比分析',
    structure: [
      '## 背景介绍\n\n为什么需要对比{topic}相关技术',
      '## 技术概览\n\n各种{topic}技术的基本介绍',
      '## 详细对比\n\n从多个维度对比不同技术的优缺点',
      '## 选择建议\n\n不同场景下的技术选型建议',
      '## 实际应用\n\n真实项目中的应用案例',
      '## 总结\n\n对比分析的结论和建议'
    ]
  },
  practice: {
    title: '{topic} - 生产实践总结',
    structure: [
      '## 项目背景\n\n介绍使用{topic}的项目背景',
      '## 架构设计\n\n系统的整体架构设计思路',
      '## 实施过程\n\n详细的项目实施过程和遇到的问题',
      '## 踩坑记录\n\n- 问题描述\n- 原因分析\n- 解决方案',
      '## 性能数据\n\n实际运行中的性能表现数据',
      '## 经验总结\n\n项目完成后的经验教训总结'
    ]
  }
};

class BlogArticleGenerator {
  constructor() {
    this.projectRoot = '/Users/chaneychan/CodeProjects/buuuuuuug.github.io';
    this.contentDir = path.join(this.projectRoot, 'src/content/blog');
    this.author = 'ChaneyChan';
  }

  /**
   * 生成文章
   */
  generateArticle(options = {}) {
    const {
      topic = 'java',
      type = 'tutorial',
      categoryIndex = 0,
      featured = false,
      draft = false
    } = options;

    const topicConfig = TECH_TOPICS[topic];
    if (!topicConfig) {
      throw new Error(`不支持的主题: ${topic}`);
    }

    const template = ARTICLE_TEMPLATES[type];
    const category = topicConfig.categories[categoryIndex] || topicConfig.categories[0];
    
    // 生成文章数据
    const articleData = {
      title: template.title.replace('{topic}', category),
      slug: this.generateSlug(category),
      description: this.generateDescription(category),
      content: this.generateContent(category, template, topic),
      tags: topicConfig.tags,
      topic,
      type,
      featured,
      draft
    };

    return articleData;
  }

  /**
   * 生成文章文件
   */
  createArticleFile(articleData) {
    const { topic, slug } = articleData;
    const topicDir = path.join(this.contentDir, topic);
    
    // 确保主题目录存在
    if (!fs.existsSync(topicDir)) {
      fs.mkdirSync(topicDir, { recursive: true });
    }

    const filePath = path.join(topicDir, `${slug}.md`);
    const content = this.formatArticleContent(articleData);

    fs.writeFileSync(filePath, content, 'utf8');
    console.log(`✅ 文章已生成: ${filePath}`);
    
    return filePath;
  }

  /**
   * 批量生成文章
   */
  generateBatchArticles(count = 5) {
    const articles = [];
    const topics = Object.keys(TECH_TOPICS);
    const types = Object.keys(ARTICLE_TEMPLATES);

    for (let i = 0; i < count; i++) {
      const topic = topics[i % topics.length];
      const type = types[i % types.length];
      const categoryIndex = Math.floor(Math.random() * TECH_TOPICS[topic].categories.length);
      
      try {
        const articleData = this.generateArticle({
          topic,
          type,
          categoryIndex,
          featured: i < 2, // 前两篇设为精选
          draft: false
        });
        
        const filePath = this.createArticleFile(articleData);
        articles.push({
          title: articleData.title,
          filePath,
          topic: articleData.topic,
          type: articleData.type
        });
      } catch (error) {
        console.error(`生成文章失败: ${error.message}`);
      }
    }

    return articles;
  }

  /**
   * 生成文章slug
   */
  generateSlug(title) {
    return title.toLowerCase()
      .replace(/[^\u4e00-\u9fa5a-zA-Z0-9\s]/g, '')
      .replace(/\s+/g, '-')
      .substring(0, 50);
  }

  /**
   * 生成文章描述
   */
  generateDescription(category) {
    const descriptions = [
      `深入解析${category}的核心概念和实践经验`,
      `${category}实战指南 - 从零到生产环境`,
      `基于${category}的项目实践总结与踩坑记录`,
      `${category}技术对比分析与选型建议`,
      `${category}性能优化实战技巧总结`
    ];
    
    return descriptions[Math.floor(Math.random() * descriptions.length)];
  }

  /**
   * 生成文章内容
   */
  generateContent(category, template, topic) {
    const sections = template.structure.map(section => 
      section.replace(/\{topic\}/g, category)
    );

    // 添加一些技术细节和代码示例
    const technicalDetails = this.generateTechnicalDetails(topic, category);
    sections.push(technicalDetails);

    return sections.join('\n\n');
  }

  /**
   * 生成技术细节和代码示例
   */
  generateTechnicalDetails(topic, category) {
    const codeExamples = {
      java: `\`\`\`java
// ${category}相关代码示例
public class Example {
    public static void main(String[] args) {
        System.out.println("${category}实践示例");
        // TODO: 添加具体实现
    }
}
\`\`\``,
      rust: `\`\`\`rust
// ${category}相关代码示例
fn main() {
    println!("${category}实践示例");
    // TODO: 添加具体实现
}
\`\`\``,
      ai: `\`\`\`python
# ${category}相关代码示例
import numpy as np
import matplotlib.pyplot as plt

print("${category}实践示例")
# TODO: 添加具体实现
\`\`\``,
      database: `\`\`\`sql
-- ${category}相关SQL示例
SELECT * FROM example_table
WHERE condition = '${category}';
-- TODO: 添加具体实现
\`\`\``,
      devops: `\`\`\`yaml
# ${category}相关配置示例
version: '3.8'
services:
  app:
    image: example:latest
    environment:
      - TOPIC=${category}
# TODO: 添加具体实现
\`\`\``
    };

    return `## 技术细节\n\n${codeExamples[topic] || codeExamples.java}\n\n> 本文介绍了${category}的核心概念和实践经验，更多详细内容请参考相关文档。`;
  }

  /**
   * 格式化文章内容
   */
  formatArticleContent(articleData) {
    const now = new Date();
    const pubDatetime = now.toISOString();
    const modDatetime = now.toISOString();

    const frontmatter = `---
author: ${this.author}
pubDatetime: ${pubDatetime}
modDatetime: ${modDatetime}
title: ${articleData.title}
slug: ${articleData.slug}
featured: ${articleData.featured}
draft: ${articleData.draft}
tags:
${articleData.tags.map(tag => `  - ${tag}`).join('\n')}
description: ${articleData.description}
---

## Table of contents

${articleData.content}`;

    return frontmatter;
  }

  /**
   * 验证项目结构
   */
  validateProject() {
    const requiredDirs = [
      this.contentDir,
      path.join(this.projectRoot, '.github', 'workflows')
    ];

    const missingDirs = requiredDirs.filter(dir => !fs.existsSync(dir));
    
    if (missingDirs.length > 0) {
      throw new Error(`项目结构不完整，缺少以下目录:\n${missingDirs.join('\n')}`);
    }

    console.log('✅ 项目结构验证通过');
    return true;
  }

  /**
   * 获取文章统计信息
   */
  getArticleStats() {
    const stats = {
      total: 0,
      byTopic: {},
      byType: {}
    };

    Object.keys(TECH_TOPICS).forEach(topic => {
      const topicDir = path.join(this.contentDir, topic);
      if (fs.existsSync(topicDir)) {
        const files = fs.readdirSync(topicDir).filter(file => file.endsWith('.md'));
        stats.byTopic[topic] = files.length;
        stats.total += files.length;
      } else {
        stats.byTopic[topic] = 0;
      }
    });

    return stats;
  }
}

// CLI接口
if (require.main === module) {
  const generator = new BlogArticleGenerator();
  
  const args = process.argv.slice(2);
  const command = args[0];

  try {
    switch (command) {
      case 'validate':
        generator.validateProject();
        break;
      
      case 'generate':
        const options = {
          topic: args[1] || 'java',
          type: args[2] || 'tutorial',
          featured: args.includes('--featured'),
          draft: args.includes('--draft')
        };
        
        const article = generator.generateArticle(options);
        const filePath = generator.createArticleFile(article);
        console.log(`📝 文章生成成功: ${filePath}`);
        break;
      
      case 'batch':
        const count = parseInt(args[1]) || 5;
        const articles = generator.generateBatchArticles(count);
        console.log(`🚀 批量生成完成，共生成 ${articles.length} 篇文章`);
        articles.forEach(article => {
          console.log(`  - ${article.title} (${article.topic})`);
        });
        break;
      
      case 'stats':
        const stats = generator.getArticleStats();
        console.log('📊 文章统计信息:');
        console.log(`总文章数: ${stats.total}`);
        Object.entries(stats.byTopic).forEach(([topic, count]) => {
          console.log(`  ${topic}: ${count} 篇`);
        });
        break;
      
      default:
        console.log(`
📝 技术博客文章生成器

使用方法:
  node blog-generator.js validate              - 验证项目结构
  node blog-generator.js generate [topic] [type] [options] - 生成单篇文章
  node blog-generator.js batch [count]         - 批量生成文章
  node blog-generator.js stats                 - 查看文章统计

参数:
  topic: java | rust | ai | database | devops (默认: java)
  type: tutorial | comparison | practice (默认: tutorial)
  options: --featured | --draft

示例:
  node blog-generator.js generate java tutorial --featured
  node blog-generator.js batch 10
  node blog-generator.js generate rust practice --draft
        `);
    }
  } catch (error) {
    console.error(`❌ 错误: ${error.message}`);
    process.exit(1);
  }
}

module.exports = BlogArticleGenerator;